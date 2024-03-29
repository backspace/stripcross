import Router from 'koa-router';
import { JSDOM } from 'jsdom';
import { addDays, format, isToday, parse } from 'date-fns';
import 'cross-fetch/polyfill';
import style from '../style';
import { getClient } from '../redis';

const DATE_FORMAT = process.env.DATE_FORMAT!;
const PATH_TEMPLATE = process.env.PATH_TEMPLATE!;

export const STRIPCROSS_PATH_DATE_FORMAT = 'y-MM-dd';
export const STRIPCROSS_LINK_DATE_FORMAT = 'EEEE MMMM d';

function determineRequestPath(originPath: string) {
  let requestDate;
  let requestDateString;

  if (originPath === '/') {
    requestDate = new Date();
    requestDateString = format(requestDate, DATE_FORMAT);
  } else {
    const originDateString = originPath.substring(1);
    const parsedDate = parse(originDateString, STRIPCROSS_PATH_DATE_FORMAT, new Date());
    requestDateString = format(parsedDate, DATE_FORMAT);
    requestDate = parsedDate;
  }

  return {
    path: PATH_TEMPLATE.replace('FORMATTED_DATE', requestDateString),
    date: requestDate,
    requestDateString,
  };
}

function extractSelector(document: Document, selector: string) {
  const element = document.querySelector(selector);
  return element?.outerHTML || '';
}

function extractSelectors(document: Document, selectors: string[]) {
  return selectors.map(selector => extractSelector(document, selector)).join('\n');
}

const register = (router: Router) => {
  router.get('/favicon.ico', async ctx => {
    ctx.status = 404;
  });

  router.get('/*', async ctx => {
    const redis = getClient();

    const { date, path } = determineRequestPath(ctx.request.path);
    ctx.status = 200;

    const hidePuzzle = ctx.query['hide-puzzle'] === '';
    const hideClues = ctx.query['hide-clues'] === '';

    const breakCache = ctx.query['break-cache'] === '';

    const cachePath = format(date, STRIPCROSS_PATH_DATE_FORMAT);

    let cached;

    if (!breakCache) {
      try {
        cached = await redis.get(cachePath);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.log('Error checking cache', e);
      }
    }

    let html;

    if (cached) {
      html = cached;
    } else {
      const url = `${process.env.BASE_HOST}${path}`;
      let original;

      try {
        original = await fetch(url, {
          headers: {
            'User-Agent': ctx.request.headers['user-agent'],
          },
        });
      } catch (e) {
        // eslint-disable-next-line no-console
        console.log(`Error fetching ${url}`, e);

        ctx.status = 400;
        ctx.body = 'Unknown error';
        return;
      }

      html = await original.text();
    }

    const htmlWithoutColons = html.replace(/ : </g, '<');

    const { document } = new JSDOM(htmlWithoutColons).window;

    if (!document.querySelector(process.env.PUZZLE_SELECTOR!)) {
      ctx.body =
        '<html><head><title>Puzzle not found</title><body>No puzzle was found. Is the date correct?</body></html>';
      ctx.status = 404;
      return;
    }

    let warning = '';
    const cellClasses = new Set();

    document.querySelectorAll(`${process.env.PUZZLE_SELECTOR} td`).forEach(cell => {
      cell.classList.forEach(className => cellClasses.add(className));
    });

    process.env.PUZZLE_CLASS_MAPPINGS?.split(' ').forEach(selector => {
      const [oldClass] = selector.split(':');
      cellClasses.delete(oldClass);
    });

    if (cellClasses.size > 0) {
      warning = `<div class='warning'>Puzzle contains unknown class(es): ${Array.from(cellClasses.values()).join(
        ', ',
      )}</div>`;
    }

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

    let links = '<a class="break-cache" id="break-cache" href="?break-cache">Refetch from source</a>';

    if (hidePuzzle) {
      links += '<a class="puzzle-toggle" id="show-puzzle" href="?">Show puzzle</a>';
    } else {
      links += '<a class="puzzle-toggle" id="hide-puzzle" href="?hide-puzzle">Hide puzzle</a>';
    }

    if (hideClues) {
      links += '<a class="clues-toggle" id="show-clues" href="?">Show clues</a>';
    } else {
      links += '<a class="clues-toggle" id="hide-clues" href="?hide-clues">Hide clues</a>';
    }

    const queryStringToAppend = ctx.querystring.length > 0 ? `?${ctx.querystring.replace('break-cache', '')}` : '';

    const previousDate = addDays(date, -1);
    links += `<a class="previous" href="${format(
      previousDate,
      STRIPCROSS_PATH_DATE_FORMAT,
    )}${queryStringToAppend}">« ${format(previousDate, STRIPCROSS_LINK_DATE_FORMAT)}</a>`;

    if (!isToday(date)) {
      const nextDate = addDays(date, 1);
      links += `<a class="next" href="${format(nextDate, STRIPCROSS_PATH_DATE_FORMAT)}${queryStringToAppend}">${format(
        nextDate,
        STRIPCROSS_LINK_DATE_FORMAT,
      )} »</a>`;
    }

    const newDocumentString = `
        <html>
            <head>
              <style>${style()}</style>
            </head>
            <body class="${hidePuzzle ? 'hide-puzzle' : ''} ${hideClues ? 'hide-clues' : ''}">
                ${extractSelectors(document, process.env.PASSTHROUGH_SELECTORS!.split(' '))}
                ${extractSelector(document, 'h1:first-of-type')}
                ${extractSelector(document, 'h1 + h2:first-of-type')}
                ${warning}
                ${links}
                ${extractSelector(document, process.env.PUZZLE_SELECTOR!)}
                ${extractSelector(document, process.env.CLUES_SELECTOR!)}
            </body>
        </html>
    `;

    ctx.body = newDocumentString;

    try {
      await redis.set(cachePath, html);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.log('Error writing to cache', e);
    }
  });
};

export default { register };
