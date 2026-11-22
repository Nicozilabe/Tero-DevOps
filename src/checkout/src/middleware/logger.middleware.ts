import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  use(request: Request, response: Response, next: NextFunction) {
    if (request.originalUrl === '/health') {
      next();
      return;
    }

    const startAt = process.hrtime();
    const { ip, method, originalUrl } = request;

    response.on('finish', () => {
      const { statusCode } = response;
      const contentLength = response.get('content-length');
      const diff = process.hrtime(startAt);
      const responseTime = diff[0] * 1e3 + diff[1] * 1e-6;
      const level = statusCode >= 500 ? 'error' : statusCode >= 400 ? 'warn' : 'info';

      console.log(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          level,
          service: 'checkout',
          event: 'http_request',
          method,
          path: originalUrl,
          status: statusCode,
          duration_ms: Number(responseTime.toFixed(2)),
          content_length: contentLength || null,
          ip,
        }),
      );
    });

    next();
  }
}
