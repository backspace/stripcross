import fetchMock from 'jest-fetch-mock';
import request from 'supertest';
import type { Server } from 'http';
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
    fetchMock.mockResponse('a response');

    const response = await request(server).get('/');
    expect(response.text).toEqual('a response');
  });
});
