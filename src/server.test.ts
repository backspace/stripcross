import fetchMock from 'jest-fetch-mock';
import request from 'supertest';
import { createClient } from 'redis';
import { Server } from 'http';
import { JSDOM } from 'jsdom';
import { addDays, format } from 'date-fns';
import { createServer } from './server';
import { connect, getClient, disconnect } from './redis';

// FIXME what doesn’t importing these work
const STRIPCROSS_PATH_DATE_FORMAT = 'y-MM-dd';
const STRIPCROSS_LINK_DATE_FORMAT = 'EEEE MMMM d';

const DATE_FORMAT = process.env.DATE_FORMAT!;

fetchMock.enableMocks();

describe('stripcross', () => {
  let server: Server;
  let redis: ReturnType<typeof createClient>;

  beforeEach(async () => {
    const app = createServer();

    await new Promise(resolve => {
      server = app.listen(() => {
        resolve(true);
      });
    });

    fetchMock.resetMocks();

    await connect();
    redis = getClient();
  });

  afterEach(async () => {
    await redis.flushAll();
    await disconnect();
  });

  test('/', async () => {
    fetchMock.mockResponse(`
        <html>
            <head>
            <title>Hello</title>
            </head>
            <body>
            <div id=ignored>this is ignored</div>
            <h1 id=Title></h1>
            <h2 id=Subtitle></h2>
            <div id=Passthrough>something</div>
            <table id=Puzzle>
                <tr><td id=preserved>this is preserved</td></tr>
                <tr>
                <td class=letter>this is removed</td>
                <td class="something"></td>
                <td class="something-else"></td>
                </tr>
            </table>
            <div id=Clues>
                <div>1</div>
                <div id=preservedclue>A clue : <a>AN ANSWER</a></div>
            </div>
            <div id=OtherPassthrough></div>
            <div>
                <h1 id=IgnoredTitle></h1>
                <h2 id=IgnoredSubtitle></h2>
            </div>
            </body>
        </html>
    `);

    let response = await request(server)
      .get('/')
      .set('User-Agent', 'ACAB');
    let { document } = new JSDOM(response.text).window;

    expect(fetchMock.mock.calls[0][0]).toContain(format(new Date(), DATE_FORMAT));
    expect(fetchMock.mock.calls[0][1]).toEqual({ headers: { 'User-Agent': 'ACAB' } });

    expect(document.querySelector('body.hide-puzzle')).toBeNull();
    expect(document.querySelector('body.hide-clues')).toBeNull();
    expect(document.querySelector('#hide-puzzle')).not.toBeNull();
    expect(document.querySelector('#show-puzzle')).toBeNull();
    expect(document.querySelector('#hide-clues')).not.toBeNull();
    expect(document.querySelector('#show-clues')).toBeNull();

    const previousLink = document.querySelector('a.previous');
    const previousDate = addDays(new Date(), -1);

    expect(previousLink?.innerHTML).toContain(format(previousDate, STRIPCROSS_LINK_DATE_FORMAT));
    expect(previousLink?.attributes.getNamedItem('href')!.value).toBe(
      format(previousDate, STRIPCROSS_PATH_DATE_FORMAT),
    );

    expect(document.querySelector('a.next')).toBeNull();

    expect(document.querySelector('#Title')).not.toBeNull();
    expect(document.querySelector('#Subtitle')).not.toBeNull();

    expect(document.querySelector('#ignored')).toBeNull();
    expect(document.querySelector('.letter')).toBeNull();

    expect(document.querySelector('#preserved')).not.toBeNull();
    expect(document.querySelector('#preservedclue')).not.toBeNull();

    expect(document.querySelector('.something')).toBeNull();
    expect(document.querySelector('.transformed-something')).not.toBeNull();

    expect(document.querySelector('.something-else')).toBeNull();
    expect(document.querySelector('.transformed-something-else')).not.toBeNull();

    expect(document.querySelector('#Clues a')).toBeNull();

    expect(response.text).not.toContain('A clue :');
    expect(response.text).not.toContain('A clue:');

    expect(document.querySelector('#Passthrough')).not.toBeNull();
    expect(document.querySelector('#OtherPassthrough')).not.toBeNull();
    expect(document.querySelector('#FakePassthrough')).toBeNull();

    response = await request(server).get('/2019-01-01?hide-puzzle');
    document = new JSDOM(response.text).window.document;

    expect(fetchMock.mock.calls[1][0]).toEqual('/20190101.html');

    expect(document.querySelector('body.hide-puzzle')).not.toBeNull();
    expect(document.querySelector('#hide-puzzle')).toBeNull();
    expect(document.querySelector('#show-puzzle')).not.toBeNull();

    const nextLink = document.querySelector('a.next');
    const nextDate = addDays(new Date(2019, 0, 1), 1);

    expect(nextLink?.innerHTML).toContain(format(nextDate, STRIPCROSS_LINK_DATE_FORMAT));
    expect(nextLink?.attributes.getNamedItem('href')!.value).toBe(format(nextDate, STRIPCROSS_PATH_DATE_FORMAT));

    response = await request(server).get('/2019-01-01?hide-clues');
    document = new JSDOM(response.text).window.document;

    expect(document.querySelector('body.hide-clues')).not.toBeNull();
    expect(document.querySelector('#hide-clues')).toBeNull();
    expect(document.querySelector('#show-clues')).not.toBeNull();
  });

  test('warns on unknown classes', async () => {
    fetchMock.mockResponse(`
        <html>
            <head>
            <title>Hello</title>
            </head>
            <body>
            <div id=ignored>this is ignored</div>
            <h1 id=Title></h1>
            <h2 id=Subtitle></h2>
            <div id=Passthrough>something</div>
            <table id=Puzzle>
                <tr><td id=preserved>this is preserved</td></tr>
                <tr>
                <td class=unknown></td>
                <td class="something"></td>
                <td class="something-else"></td>
                </tr>
            </table>
            <div id=Clues>
                <div>1</div>
                <div id=preservedclue>A clue : <a>AN ANSWER</a></div>
            </div>
            <div id=OtherPassthrough></div>
            <div>
                <h1 id=IgnoredTitle></h1>
                <h2 id=IgnoredSubtitle></h2>
            </div>
            </body>
        </html>
    `);

    const response = await request(server).get('/');
    const { document } = new JSDOM(response.text).window;

    expect(document.querySelector('.warning')?.innerHTML).toEqual('Puzzle contains unknown class(es): unknown');
  });

  test('cache can be refreshed', async () => {
    await redis.set(
      '2006-05-26',
      `
        <html>
            <head>
            <title>Hello</title>
            </head>
            <body>
            <div id=ignored>this is ignored</div>
            <h1 id=Title>Cached</h1>
            <h2 id=Subtitle></h2>
            <div id=Passthrough>something</div>
            <table id=Puzzle>
            </table>
            <div id=Clues>
            </div>
            </body>
        </html>
    `,
    );

    fetchMock.mockResponse(`
        <html>
            <head>
            <title>Hello</title>
            </head>
            <body>
            <div id=ignored>this is ignored</div>
            <h1 id=Title>Not cached</h1>
            <h2 id=Subtitle></h2>
            <div id=Passthrough>something</div>
            <table id=Puzzle>
            </table>
            <div id=Clues>
            </div>
            </body>
        </html>
    `);

    const response = await request(server).get('/2006-05-26?break-cache');
    const { document } = new JSDOM(response.text).window;

    expect(fetchMock.mock.calls.length).toEqual(1);
    expect(document.querySelector('#Title')?.innerHTML).toEqual('Not cached');
  });

  test('missing puzzle is detected and not cached', async () => {
    fetchMock.mockResponse(`
        <html>
            <head>
            <title>Hello</title>
            </head>
            <body>
            <div id=ignored>this is ignored</div>
            <h1 id=Title>Not cached</h1>
            <h2 id=Subtitle></h2>
            <div id=Passthrough>something</div>
            <div id=Clues>
            </div>
            </body>
        </html>
    `);

    const response = await request(server).get('/2006-05-26');
    const { document } = new JSDOM(response.text).window;

    expect(fetchMock.mock.calls.length).toEqual(1);
    expect(document.querySelector('title')?.innerHTML).toContain('not found');

    expect(await redis.dbSize()).toEqual(0);
  });
});
