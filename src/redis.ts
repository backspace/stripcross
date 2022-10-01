import { createClient, RedisClientOptions } from 'redis';

const redisConfig: RedisClientOptions = {};

if (process.env.REDIS_URL) {
  redisConfig.url = process.env.REDIS_URL;
}

let redis: ReturnType<typeof createClient>;

export async function connect() {
  try {
    redis = createClient(redisConfig);

    const connectPromise = new Promise(resolve => {
      redis.on('connect', () => {
        // eslint-disable-next-line no-console
        console.log('Redis connected', new Date().toISOString());
        resolve(true);
      });
    });

    redis.on('error', (e: any) => {
      // eslint-disable-next-line no-console
      console.error('Redis error', e);
    });

    redis.connect();
    await connectPromise;
  } catch (e) {
    // eslint-disable-next-line no-console
    console.log('Error connecting cache', e);
  }
}

export function getClient() {
  return redis;
}

export async function disconnect() {
  try {
    redis.disconnect();
  } catch (e) {
    // eslint-disable-next-line-no-console
    console.log('Error disconnecting cache', e);
  }
}
