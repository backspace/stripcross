import Router from 'koa-router';
import { JSDOM } from 'jsdom';
import 'cross-fetch';

function extractSelector(document: Document, selector: string) {
  const element = document.querySelector(selector);
  return element?.outerHTML || '';
}

const register = (router: Router) => {
  router.get('/', async ctx => {
    ctx.status = 200;

    const original = await fetch(`${process.env.BASE_HOST}`);
    const html = await original.text();

    const { document } = new JSDOM(html).window;

    process.env.REMOVE_SELECTORS?.split(' ').forEach(selector => {
      document.querySelectorAll(selector).forEach(element => element.remove());
    });

    const newDocumentString = `
        <html>
            <body>
                ${extractSelector(document, 'h1:first-of-type')}
                ${extractSelector(document, 'h1 + h2:first-of-type')}
                ${extractSelector(document, process.env.PUZZLE_SELECTOR!)}
                ${extractSelector(document, process.env.CLUES_SELECTOR!)}
            </body>
        </html>
    `;

    ctx.body = newDocumentString;
  });
};

export default { register };
