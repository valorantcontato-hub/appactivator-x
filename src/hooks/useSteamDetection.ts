import { useCallback, useEffect, useState } from "react";
import type { SteamInfo } from "@/types";
import { getBackend } from "@/services";

export function useSteamDetection() {
  const [info, setInfo] = useState<SteamInfo | null>(null);
  const [scanning, setScanning] = useState(false);

  const scan = useCallback(async () => {
    setScanning(true);
    try {
      setInfo(await getBackend().detectSteam());
    } finally {
      setScanning(false);
    }
  }, []);

  const setPath = useCallback(async (path: string) => {
    setScanning(true);
    try {
      setInfo(await getBackend().setSteamPath(path));
    } finally {
      setScanning(false);
    }
  }, []);

  useEffect(() => {
    void scan();
  }, [scan]);

  return { info, scanning, scan, setPath };
}
