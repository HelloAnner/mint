export class MintError extends Error {
  readonly code: string
  readonly hint?: string

  constructor(code: string, message: string, hint?: string) {
    super(message)
    this.name = 'MintError'
    this.code = code
    this.hint = hint
  }
}

export function fail(code: string, message: string, hint?: string): never {
  throw new MintError(code, message, hint)
}
