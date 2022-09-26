import fetchMock from 'jest-fetch-mock';
import request from 'supertest';
import type { Server } from 'http';
import { JSDOM } from 'jsdom';
import { addDays, format } from 'date-fns';
import { createServer } from './server';

// FIXME what doesn’t importing these work
const STRIPCROSS_PATH_DATE_FORMAT = 'y-MM-dd';
const STRIPCROSS_LINK_DATE_FORMAT = 'EEEE MMMM d';

const DATE_FORMAT = process.env.DATE_FORMAT!;

fetchMock.enableMocks();

describe('stripcross', () => {
  let server: Server;

  beforeEach((done) => {
    const app = createServer();
    server = app.listen(() => done());
    fetchMock.resetMocks();
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

    let response = await request(server).get('/');
    let { document } = new JSDOM(response.text).window;

    expect(fetchMock.mock.calls[0][0]).toContain(format(new Date(), DATE_FORMAT));

    expect(document.querySelector('body.hide-puzzle')).toBeNull();
    expect(document.querySelector('#hide-puzzle')).not.toBeNull();
    expect(document.querySelector('#show-puzzle')).toBeNull();

    const previousLink = document.querySelector('a.previous');
    const previousDate = addDays(new Date(), -1);

    expect(previousLink?.innerHTML).toContain(format(previousDate, STRIPCROSS_LINK_DATE_FORMAT));
    expect(previousLink?.attributes.getNamedItem('href')!.value).toBe(format(previousDate, STRIPCROSS_PATH_DATE_FORMAT));

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
  });
});
