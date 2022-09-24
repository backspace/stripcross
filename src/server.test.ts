import fetchMock from 'jest-fetch-mock';
import request from 'supertest';
import type { Server } from 'http';
import { JSDOM } from 'jsdom';
import { createServer } from './server';

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

    const response = await request(server).get('/');

    const { document } = new JSDOM(response.text).window;

    expect(document.querySelector('#Title')).not.toBeNull();
    expect(document.querySelector('#Subtitle')).not.toBeNull();

    expect(document.querySelector('#ignored')).toBeNull();
    expect(document.querySelector('.letter')).toBeNull();

    expect(document.querySelector('#preserved')).not.toBeNull();
    expect(document.querySelector('#preservedclue')).not.toBeNull();
  });
});
