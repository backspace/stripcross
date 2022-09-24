import Router from 'koa-router';
import IndexRoute from './routes';
import HealthRoutes from './routes/health';

const router = new Router();

IndexRoute.register(router);
HealthRoutes.register(router);

export { router };
