const BOX_QR_PREFIX = 'rechibox://box/';
const PUBLIC_ID_PATTERN = /^[0-9a-f]{32}$/;

export function buildBoxQrPayload(publicId: string): string {
  const normalizedPublicId = publicId.trim().toLowerCase();

  if (!PUBLIC_ID_PATTERN.test(normalizedPublicId)) {
    throw new Error('Invalid box public id');
  }

  return `${BOX_QR_PREFIX}${normalizedPublicId}`;
}

export function parseBoxQrPayload(value: string): string | null {
  const normalizedValue = value.trim().toLowerCase();

  if (!normalizedValue.startsWith(BOX_QR_PREFIX)) {
    return null;
  }

  const publicId = normalizedValue.slice(BOX_QR_PREFIX.length);
  return PUBLIC_ID_PATTERN.test(publicId) ? publicId : null;
}
