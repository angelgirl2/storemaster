// Dedicated entry point for Store Master Pro Cloudflare deployment.
// Reuses the reviewed Store Master failover implementation while publishing
// it as a separate Worker with its own Durable Object namespace/configuration.
export { default } from "../../cloudflare/src/index.js";
export { FailoverState } from "../../cloudflare/src/index.js";
