package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"retail-store/catalog/api"
	"retail-store/catalog/config"
	"retail-store/catalog/controller"
	"retail-store/catalog/middleware"
	"retail-store/catalog/repository"

	"github.com/gin-gonic/gin"
	"github.com/sethvargo/go-envconfig/pkg/envconfig"
	ginprometheus "github.com/zsais/go-gin-prometheus"

	"go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// @title Catalog API
// @version 1.0
// @description This API serves the product catalog

// @license.name Apache 2.0
// @license.url http://www.apache.org/licenses/LICENSE-2.0.html

// @host localhost:8080
// @BasePath /

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	ctx := context.Background()

	if _, otelPresent := os.LookupEnv("OTEL_SERVICE_NAME"); otelPresent {
		if _, err := initTracer(ctx); err != nil {
			log.Fatal(err)
		}
	}

	var cfg config.AppConfiguration
	if err := envconfig.Process(ctx, &cfg); err != nil {
		log.Fatal(err)
	}

	db, err := repository.NewRepository(cfg.Database)
	if err != nil {
		log.Fatal(err)
	}

	catalogAPI, err := api.NewCatalogAPI(db)
	if err != nil {
		log.Fatal(err)
	}

	c, err := controller.NewController(catalogAPI)
	if err != nil {
		log.Fatalln("Error creating controller", err)
	}

	chaosController := middleware.NewChaosController()
	r := setupRouter(cfg, c, chaosController)

	srv := &http.Server{
		Addr:              ":" + strconv.Itoa(cfg.Port),
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	slog.Info("server_started", "service", "catalog", "port", cfg.Port, "version", cfg.Version, "chaos_enabled", cfg.EnableChaos)

	// Initializing the server in a goroutine so that
	// it won't block the graceful shutdown handling below
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server with
	// a timeout of 5 seconds.
	quit := make(chan os.Signal, 1)
	// kill (no param) default send syscall.SIGTERM
	// kill -2 is syscall.SIGINT
	// kill -9 is syscall.SIGKILL but can't be catch, so don't need add it
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	// The context is used to inform the server it has 5 seconds to finish
	// the request it is currently handling
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exiting")
}

func setupRouter(cfg config.AppConfiguration, c *controller.Controller, chaosController *middleware.ChaosController) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(gin.LoggerWithConfig(newJSONLoggerConfig()))

	p := ginprometheus.NewPrometheus("gin")
	p.Use(r)

	if cfg.EnableChaos {
		chaosController.SetupChaosRoutes(r)
	}

	catalog := r.Group("/catalog")
	catalog.Use(chaosController.ChaosMiddleware())
	catalog.Use(otelgin.Middleware("catalog-server"))

	catalog.GET("/products", c.GetProducts)
	catalog.GET("/size", c.CatalogSize)
	catalog.GET("/tags", c.ListTags)
	catalog.GET("/products/:id", c.GetProduct)

	r.GET("/health", func(c *gin.Context) {
		if !chaosController.IsHealthy() {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"status":  "unhealthy",
				"service": "catalog",
				"version": cfg.Version,
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "catalog",
			"version": cfg.Version,
		})
	})

	r.GET("/topology", func(c *gin.Context) {
		topology := map[string]string{
			"persistenceProvider": cfg.Database.Type,
			"databaseEndpoint":    "N/A",
		}
		if cfg.Database.Type != "in-memory" {
			topology["databaseEndpoint"] = cfg.Database.Endpoint
		}
		c.JSON(http.StatusOK, topology)
	})

	return r
}

func newJSONLoggerConfig() gin.LoggerConfig {
	return gin.LoggerConfig{
		SkipPaths: []string{"/health", "/metrics"},
		Formatter: func(param gin.LogFormatterParams) string {
			level := "info"
			if param.StatusCode >= 500 {
				level = "error"
			} else if param.StatusCode >= 400 {
				level = "warn"
			}
			entry := map[string]any{
				"timestamp":   param.TimeStamp.UTC().Format(time.RFC3339Nano),
				"level":       level,
				"service":     "catalog",
				"event":       "http_request",
				"method":      param.Method,
				"path":        param.Path,
				"status":      param.StatusCode,
				"duration_ms": float64(param.Latency.Microseconds()) / 1000.0,
				"client_ip":   param.ClientIP,
			}
			b, err := json.Marshal(entry)
			if err != nil {
				return ""
			}
			return string(b) + "\n"
		},
	}
}

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	client := otlptracehttp.NewClient()
	exporter, err := otlptrace.New(ctx, client)
	if err != nil {
		return nil, fmt.Errorf("creating OTLP trace exporter: %w", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
	)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
	otel.SetTracerProvider(tp)
	return tp, nil
}
