import { afterEach, describe, expect, it, vi } from 'vitest';

/*
 * `VITE_API_BASE_URL`은 모듈을 불러올 때 읽으므로 테스트마다 환경 변수를 바꾼 뒤 모듈을 새로 불러온다.
 */
async function loadClient(baseUrl: string) {
  vi.stubEnv('VITE_API_BASE_URL', baseUrl);
  vi.resetModules();
  return import('./client');
}

function stubFetch(status: number, body: string) {
  const fetchMock = vi.fn().mockResolvedValue(new Response(body, { status }));
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('request', () => {
  it('VITE_API_BASE_URL을 출처로 /api/v1 경로에 요청한다', async () => {
    const fetchMock = stubFetch(200, '{"ok":true}');
    const { request } = await loadClient('http://localhost:8080/');

    const data = await request<{ ok: boolean }>('/health');

    expect(data).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledWith(
      'http://localhost:8080/api/v1/health',
      expect.objectContaining({ method: 'GET' }),
    );
  });

  it('VITE_API_BASE_URL이 비면 같은 출처로 요청한다', async () => {
    const fetchMock = stubFetch(200, '');
    const { request } = await loadClient('');

    const data = await request<void>('/health', { method: 'DELETE' });

    expect(data).toBeUndefined();
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/v1/health',
      expect.objectContaining({ method: 'DELETE' }),
    );
  });

  it('2xx가 아니면 상태 코드와 본문을 담은 ApiError를 던진다', async () => {
    stubFetch(403, '{"code":"FORBIDDEN"}');
    const { request, ApiError } = await loadClient('');

    const error = await request('/admin').catch((e: unknown) => e);

    expect(error).toBeInstanceOf(ApiError);
    expect(error).toMatchObject({ status: 403, body: { code: 'FORBIDDEN' } });
  });
});
