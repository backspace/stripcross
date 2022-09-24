import Router from 'koa-router';
import IndexRoute from './routes';

const router = new Router();

IndexRoute.register(router);

export { router };
