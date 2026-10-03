/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** API 서버 출처. 비우면 같은 출처로 요청한다(.env.example) */
  readonly VITE_API_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
