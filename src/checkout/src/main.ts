import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe());
  app.enableShutdownHooks();

  const port = process.env.PORT || 8080;
  await app.listen(port);
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level: 'info',
      service: 'checkout',
      event: 'server_started',
      port,
      version: process.env.APP_VERSION || 'unknown',
    }),
  );
}
bootstrap();
