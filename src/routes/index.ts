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

function extractSelectors(document: Document, selectors: string[]) {
  return selectors.map(selector => extractSelector(document, selector)).join('\n');
}

const register = (router: Router) => {
  router.get('/*', async ctx => {
    const requestPath = determineRequestPath(ctx.request.path);
    ctx.status = 200;

    const hidePuzzle = ctx.query['hide-puzzle'] === '';

    const original = await fetch(`${process.env.BASE_HOST}${requestPath}`);
    const html = await original.text();
    const htmlWithoutColons = html.replace(/ : </g, '<');

    const { document } = new JSDOM(htmlWithoutColons).window;

    process.env.REMOVE_SELECTORS?.split(' ').forEach(selector => {
      document.querySelectorAll(selector).forEach(element => element.remove());
    });

    process.env.PUZZLE_CLASS_MAPPINGS?.split(' ').forEach(selector => {
      const [oldClass, newClass] = selector.split(':');
      document.querySelectorAll(`.${oldClass}`).forEach(element => {
        element.classList.remove(oldClass);
        element.classList.add(newClass);
      });
    });

    document.querySelectorAll(`${process.env.CLUES_SELECTOR} a`).forEach(element => element.remove());

    let links = '';

    if (hidePuzzle) {
      links += '<a id="show-puzzle" href="?">Show puzzle</a>';
    } else {
      links += '<a id="hide-puzzle" href="?hide-puzzle">Hide puzzle</a>';
    }

    const newDocumentString = `
        <html>
            <head>
              <style>${style()}</style>
            </head>
            <body class="${hidePuzzle ? 'hide-puzzle' : ''}">
                ${extractSelectors(document, process.env.PASSTHROUGH_SELECTORS!.split(' '))}
                ${extractSelector(document, 'h1:first-of-type')}
                ${extractSelector(document, 'h1 + h2:first-of-type')}
                ${links}
                ${extractSelector(document, process.env.PUZZLE_SELECTOR!)}
                ${extractSelector(document, process.env.CLUES_SELECTOR!)}
            </body>
        </html>
    `;

    ctx.body = newDocumentString;
  });
};

export default { register };
