import { loadEnv, defineConfig, } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())


module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL, //added based on medusa documentaion
    workerMode: process.env.MEDUSA_WORKER_MODE as "shared" | "worker" | "server", //added based on medusa documentaion
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
  },
  admin: {
    disable: process.env.DISABLE_MEDUSA_ADMIN === "true", //added based on medusa documentaion
    backendUrl: process.env.MEDUSA_BACKEND_URL,  //added based on medusa documentaion

  },
})
