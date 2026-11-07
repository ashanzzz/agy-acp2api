import http from "node:http";
import https from "node:https";
import { AddressInfo } from "node:net";

const UPSTREAM_HOST = "daily-cloudcode-pa.googleapis.com";
const UPSTREAM_BASE = `https://${UPSTREAM_HOST}`;

const sharedHttpsAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 32,
});

export class CcpaModelSniffer {
  private server: http.Server | null = null;
  private port: number = 0;
  private latestMainModelVersion: string | null = null;
  private latestFallbackModelVersion: string | null = null;
  private onModelVersionCallback?: (modelVersion: string) => void;

  public async start(onModelVersion?: (modelVersion: string) => void): Promise<number> {
    this.onModelVersionCallback = onModelVersion;

    this.server = http.createServer((req, res) => {
      const urlPath = req.url || "/";
      const isStreamGenerate = urlPath.includes("streamGenerateContent");
      const targetUrl = new URL(urlPath, UPSTREAM_BASE);

      const outHeaders: http.OutgoingHttpHeaders = {
        ...req.headers,
        host: UPSTREAM_HOST,
      };

      const upstreamReq = https.request(
        targetUrl,
        {
          method: req.method,
          headers: outHeaders,
          agent: sharedHttpsAgent,
        },
        (upstreamRes) => {
          res.writeHead(upstreamRes.statusCode || 200, upstreamRes.headers);

          if (!isStreamGenerate) {
            upstreamRes.pipe(res);
            return;
          }

          let tailBuffer = "";

          upstreamRes.on("data", (chunk: Buffer) => {
            res.write(chunk);
            try {
              const text = tailBuffer + chunk.toString("utf-8");
              if (text.includes("modelVersion")) {
                const matches = text.matchAll(/"modelVersion"\s*:\s*"([^"]+)"/g);
                for (const m of matches) {
                  const ver = m[1];
                  if (!ver) continue;
                  // `gemini-3.5-flash-lite` is used by `agy` internally for background conversation title generation
                  if (ver === "gemini-3.5-flash-lite") {
                    this.latestFallbackModelVersion = ver;
                  } else {
                    this.latestMainModelVersion = ver;
                    this.onModelVersionCallback?.(ver);
                  }
                }
              }
              tailBuffer = text.slice(-128);
            } catch {}
          });

          upstreamRes.on("end", () => {
            res.end();
          });

          upstreamRes.on("error", () => {
            res.end();
          });
        }
      );

      upstreamReq.on("error", (err) => {
        if (!res.headersSent) {
          res.writeHead(502, { "Content-Type": "application/json" });
        }
        res.end(JSON.stringify({ error: err.message }));
      });

      req.pipe(upstreamReq);
    });

    await new Promise<void>((resolve, reject) => {
      this.server!.once("error", reject);
      this.server!.listen(0, "127.0.0.1", () => {
        const addr = this.server!.address() as AddressInfo;
        this.port = addr.port;
        resolve();
      });
    });

    this.server.unref?.();
    return this.port;
  }

  public resetTurnModel(): void {
    this.latestMainModelVersion = null;
    this.latestFallbackModelVersion = null;
  }

  public getDetectedModelVersion(): string | null {
    return this.latestMainModelVersion || this.latestFallbackModelVersion;
  }

  public getPort(): number {
    return this.port;
  }

  public stop(): void {
    if (this.server) {
      try {
        this.server.close();
      } catch {}
      this.server = null;
    }
  }
}
