import { syncInventoryToWorld } from './inventory-sync';

export type WorldQueryAnswerStatus =
  | 'resolved'
  | 'ambiguous'
  | 'unknown'
  | 'conflict'
  | 'unavailable';

export type WorldQueryAnswer = {
  contract_version: string;
  status: WorldQueryAnswerStatus;
  locale: string;
  text: string | null;
  supporting_claim_ids: string[];
};

export type WorldQueryClarificationOption = {
  option_id: string;
  entity_id: string;
  label: string;
  kind: string;
};

export type WorldQueryClarification = {
  id: string;
  status: string;
  question: string;
  options: WorldQueryClarificationOption[];
};

export type NaturalWorldQueryResult = {
  mode: string;
  resolutionStatus: string | null;
  clarification: WorldQueryClarification | null;
  answer: WorldQueryAnswer | null;
};

export type WorldQueryClarificationResult = {
  clarification: WorldQueryClarification;
  answer: WorldQueryAnswer | null;
};

export type WorldQueryClientErrorCode =
  | 'not_configured'
  | 'request_failed'
  | 'invalid_response';

export class WorldQueryClientError extends Error {
  constructor(
    readonly code: WorldQueryClientErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'WorldQueryClientError';
  }
}

type JsonObject = Record<string, unknown>;

export function getWorldQueryConfiguration() {
  const apiUrl = process.env.EXPO_PUBLIC_RECHIBOX_API_URL?.trim().replace(/\/+$/, '') ?? '';

  return {
    apiUrl,
    ready: apiUrl.length > 0,
  };
}

export async function askWorld(message: string, worldId: string): Promise<NaturalWorldQueryResult> {
  const text = message.trim();
  const normalizedWorldId = worldId.trim();
  if (!text) {
    throw new WorldQueryClientError('request_failed', 'Message must not be blank.');
  }
  if (!normalizedWorldId) {
    throw new WorldQueryClientError('request_failed', 'World State id must not be blank.');
  }

  const configuration = requireConfiguration();

  try {
    await syncInventoryToWorld(normalizedWorldId, configuration.apiUrl);
  } catch {
    throw new WorldQueryClientError('request_failed', 'Could not refresh your local inventory in Rechibox.');
  }

  const payload = await postJson(
    `${configuration.apiUrl}/api/worlds/${encodeURIComponent(normalizedWorldId)}/natural_query`,
    { message: text },
  );

  return parseNaturalQueryResponse(payload);
}

export async function answerWorldClarification(
  worldId: string,
  clarificationId: string,
  optionId: string | null,
): Promise<WorldQueryClarificationResult> {
  const normalizedWorldId = worldId.trim();
  const normalizedClarificationId = clarificationId.trim();
  if (!normalizedWorldId || !normalizedClarificationId) {
    throw new WorldQueryClientError('request_failed', 'World State clarification is missing an id.');
  }

  const configuration = requireConfiguration();
  const payload = await postJson(
    `${configuration.apiUrl}/api/worlds/${encodeURIComponent(normalizedWorldId)}/natural_query/clarifications/${encodeURIComponent(normalizedClarificationId)}/answer`,
    optionId ? { action: 'select', option_id: optionId } : { action: 'none_of_above' },
  );

  const clarification = parseClarification(payload.clarification);
  if (!clarification) {
    throw new WorldQueryClientError('invalid_response', 'Backend response is missing clarification.');
  }

  return {
    clarification,
    answer: parseAnswer(payload.answer),
  };
}

function requireConfiguration() {
  const configuration = getWorldQueryConfiguration();
  if (!configuration.ready) {
    throw new WorldQueryClientError(
      'not_configured',
      'Rechibox World State backend is not configured for this build.',
    );
  }
  return configuration;
}

async function postJson(url: string, body: JsonObject): Promise<JsonObject> {
  let response: Response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch {
    throw new WorldQueryClientError('request_failed', 'Could not reach the Rechibox backend.');
  }

  const payload = await readJsonObject(response);
  if (!response.ok) {
    const detail = typeof payload.error === 'string' ? payload.error : `HTTP ${response.status}`;
    throw new WorldQueryClientError('request_failed', detail);
  }
  return payload;
}

async function readJsonObject(response: Response): Promise<JsonObject> {
  try {
    const value: unknown = await response.json();
    if (isObject(value)) return value;
  } catch {
    // The caller reports a stable contract error below.
  }

  throw new WorldQueryClientError('invalid_response', 'Backend returned invalid JSON.');
}

function parseNaturalQueryResponse(payload: JsonObject): NaturalWorldQueryResult {
  const mode = typeof payload.mode === 'string' ? payload.mode : '';
  if (!mode) {
    throw new WorldQueryClientError('invalid_response', 'Backend response is missing mode.');
  }

  const resolutionStatus = isObject(payload.resolution) && typeof payload.resolution.status === 'string'
    ? payload.resolution.status
    : null;

  return {
    mode,
    resolutionStatus,
    clarification: parseClarification(payload.clarification),
    answer: parseAnswer(payload.answer),
  };
}

function parseClarification(value: unknown): WorldQueryClarification | null {
  if (value === null || value === undefined) return null;
  if (!isObject(value)) {
    throw new WorldQueryClientError('invalid_response', 'Backend clarification has an invalid shape.');
  }

  if (
    typeof value.id !== 'string' ||
    typeof value.status !== 'string' ||
    typeof value.question !== 'string' ||
    !Array.isArray(value.options)
  ) {
    throw new WorldQueryClientError('invalid_response', 'Backend clarification has an invalid shape.');
  }

  const options = value.options.map((option) => {
    if (
      !isObject(option) ||
      typeof option.option_id !== 'string' ||
      typeof option.entity_id !== 'string' ||
      typeof option.label !== 'string' ||
      typeof option.kind !== 'string'
    ) {
      throw new WorldQueryClientError('invalid_response', 'Backend clarification option has an invalid shape.');
    }
    return {
      option_id: option.option_id,
      entity_id: option.entity_id,
      label: option.label,
      kind: option.kind,
    };
  });

  return {
    id: value.id,
    status: value.status,
    question: value.question,
    options,
  };
}

function parseAnswer(value: unknown): WorldQueryAnswer | null {
  if (value === null || value === undefined) return null;
  if (!isObject(value)) {
    throw new WorldQueryClientError('invalid_response', 'Backend answer has an invalid shape.');
  }

  const status = value.status;
  const locale = value.locale;
  const contractVersion = value.contract_version;
  const text = value.text;
  const supportingClaimIds = value.supporting_claim_ids;

  if (
    !isAnswerStatus(status) ||
    typeof locale !== 'string' ||
    typeof contractVersion !== 'string' ||
    !(typeof text === 'string' || text === null) ||
    !Array.isArray(supportingClaimIds) ||
    !supportingClaimIds.every((id) => typeof id === 'string')
  ) {
    throw new WorldQueryClientError('invalid_response', 'Backend answer has an invalid shape.');
  }

  return {
    contract_version: contractVersion,
    status,
    locale,
    text,
    supporting_claim_ids: supportingClaimIds,
  };
}

function isAnswerStatus(value: unknown): value is WorldQueryAnswerStatus {
  return (
    value === 'resolved' ||
    value === 'ambiguous' ||
    value === 'unknown' ||
    value === 'conflict' ||
    value === 'unavailable'
  );
}

function isObject(value: unknown): value is JsonObject {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
