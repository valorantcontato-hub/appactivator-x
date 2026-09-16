const KEY_PATTERN = /^[A-Z0-9]{5}(-[A-Z0-9]{5}){3}$/;

/** Normaliza a key digitada: maiúsculas, apenas alfanumérico, blocos de 5. */
export function normalizeKey(raw: string): string {
  const clean = raw
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 20);
  return clean.match(/.{1,5}/g)?.join("-") ?? "";
}

export function isKeyFormatValid(key: string): boolean {
  return KEY_PATTERN.test(key.trim().toUpperCase());
}
