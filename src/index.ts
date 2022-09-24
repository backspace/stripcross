import http from 'http';
import { createServer } from './server';
import { appConfig } from './config';

const app = createServer();

const httpServer = http.createServer(app.callback());

const { env, name, version, host, port } = appConfig;

httpServer.listen({ host, port }, () => {
  // eslint-disable-next-line no-console
  console.info(`${name}@${version} server listening on ${host}:${port}, in ${env}`);
});
