import { defineStore } from "pinia";
import { inject, ref } from "vue";
import { fetchURL } from "@/api/utils";

// 超过该大小的文件不进入浏览器内存下载（防止内存溢出），
// 改为浏览器原生下载（浏览器自身会显示下载进度）。
const MAX_MEMORY_DOWNLOAD_BYTES = 1024 * 1024 * 1024; // 1GB

// 进度刷新节流阈值（每累计 256KB 才更新一次响应式状态，避免频繁重渲染）
const PROGRESS_COMMIT_BYTES = 256 * 1024;

export const useDownloadStore = defineStore("download", () => {
  const $showError = inject<IToastError>("$showError")!;

  //
  // STATE
  //

  const activeDownloads = ref<Download[]>([]);
  const totalBytes = ref<number>(0);
  const sentBytes = ref<number>(0);

  //
  // PRIVATE FUNCTIONS
  //

  const commit = (dl: Download, bytes: number) => {
    sentBytes.value += bytes - dl.sentBytes;
    dl.sentBytes = bytes;
  };

  const remove = (dl: Download) => {
    activeDownloads.value = activeDownloads.value.filter((d) => d !== dl);
    if (activeDownloads.value.length === 0) {
      totalBytes.value = 0;
      sentBytes.value = 0;
    }
  };

  //
  // ACTIONS
  //

  const download = async (url: string, name: string) => {
    let res: Response;
    try {
      res = await fetchURL(url, {
        method: "GET",
        headers: { "Content-Type": "application/octet-stream" },
      });
    } catch (err) {
      $showError(err instanceof Error ? err : new Error(String(err)));
      return;
    }

    const total = Number(res.headers.get("Content-Length")) || 0;

    // 大文件：不占用浏览器内存，交给浏览器原生下载
    if (total > MAX_MEMORY_DOWNLOAD_BYTES) {
      const a = document.createElement("a");
      a.href = url;
      a.download = name;
      a.click();
      return;
    }

    const dl: Download = { url, name, totalBytes: total, sentBytes: 0 };
    activeDownloads.value.push(dl);
    totalBytes.value += total;

    try {
      const reader = res.body!.getReader();
      const chunks: BlobPart[] = [];
      let received = 0;
      let lastCommit = 0;

      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value) {
          chunks.push(value);
          received += value.byteLength;
          if (received - lastCommit >= PROGRESS_COMMIT_BYTES) {
            commit(dl, received);
            lastCommit = received;
          }
        }
      }

      commit(dl, received);

      const blob = new Blob(chunks);
      const blobUrl = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = blobUrl;
      a.download = name;

      // 先清理状态再触发下载：浏览器下载对话框可能阻塞后续 JS
      remove(dl);

      a.click();
      setTimeout(() => URL.revokeObjectURL(blobUrl), 5000);
    } catch (err) {
      remove(dl);
      $showError(err instanceof Error ? err : new Error(String(err)));
      return;
    }
  };

  return {
    // STATE
    activeDownloads,
    totalBytes,
    sentBytes,

    // ACTIONS
    download,
  };
});
