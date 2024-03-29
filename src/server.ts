import cors from '@koa/cors';
import Koa from 'koa';
import bodyParser from 'koa-bodyparser';
import logger from 'koa-logger';
import { bodyParserConfig, corsConfig } from './config';
import { router } from './router';

export function createServer(): Koa {
  const app = new Koa();

  app.use(logger());

  // Apply Middleware
  app.use(bodyParser(bodyParserConfig));
  app.use(cors(corsConfig));

  // Apply routes
  app.use(router.routes());

  return app;
}
