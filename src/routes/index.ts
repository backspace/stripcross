import Router from 'koa-router';
import 'cross-fetch';

const register = (router: Router) => {
  router.get('/', async ctx => {
    ctx.status = 200;

    const original = await fetch(`${process.env.BASE_HOST}`);
    const html = await original.text();

    ctx.body = html;
  });
};

export default { register };
