import Router from 'koa-router';
import { JSDOM } from 'jsdom';
import { format, parse } from 'date-fns';
import 'cross-fetch';
import style from '../style';

const DATE_FORMAT = process.env.DATE_FORMAT!;
const PATH_TEMPLATE = process.env.PATH_TEMPLATE!;

const STRIPCROSS_PATH_DATE_FORMAT = 'y-MM-dd';

function determineRequestPath(originPath: string) {
  let requestDateString;

  if (originPath === '/') {
    requestDateString = format(new Date(), DATE_FORMAT);
  } else {
    const originDateString = originPath.substring(1);
    const parsedDate = parse(originDateString, STRIPCROSS_PATH_DATE_FORMAT, new Date());
    requestDateString = format(parsedDate, DATE_FORMAT);
  }

  return PATH_TEMPLATE.replace('FORMATTED_DATE', requestDateString);
}

function extractSelector(document: Document, selector: string) {
  const element = document.querySelector(selector);
  return element?.outerHTML || '';
}

const register = (router: Router) => {
  router.get('/*', async ctx => {
    const requestPath = determineRequestPath(ctx.request.path);
    ctx.status = 200;

    const original = await fetch(`${process.env.BASE_HOST}${requestPath}`);
    const html = await original.text();

    const { document } = new JSDOM(html).window;

    process.env.REMOVE_SELECTORS?.split(' ').forEach(selector => {
      document.querySelectorAll(selector).forEach(element => element.remove());
    });

    const newDocumentString = `
        <html>
            <head>
              <style>${style()}</style>
            </head>
            <body>
                ${extractSelector(document, 'h1:first-of-type')}
                ${extractSelector(document, 'h1 + h2:first-of-type')}
                ${extractSelector(document, process.env.PUZZLE_SELECTOR!)}
                ${extractSelector(document, process.env.CLUES_SELECTOR!)}
            </body>
        </html>
    `;

    ctx.body = newDocumentString.replace(/ :/g, ':');
  });
};

export default { register };
