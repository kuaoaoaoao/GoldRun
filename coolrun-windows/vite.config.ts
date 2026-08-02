import { defineConfig } from "vite";

// Tauri 开发约定：固定端口，供 tauri.conf.json 的 devUrl 使用
export default defineConfig({
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
  },
  build: {
    target: "es2021",
  },
});
