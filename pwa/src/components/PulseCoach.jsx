const COPY = {
  ready: 'Vamos paso a paso.',
  close: 'Estás muy cerca.',
  celebrate: 'Meta completada.',
  rest: 'Recuperar también cuenta.',
  food: 'Tu energía va tomando forma.',
}

// Pulso is an original, deliberately simple vector companion. It lives in the
// interface (rather than in a pre-rendered image) so colour, motion and reduced
// motion remain part of the product system on every platform.
export default function PulseCoach({ state = 'ready', message, compact = false }) {
  return <div className={`pulse-coach ${state}${compact ? ' compact' : ''}`}>
    <svg viewBox="0 0 120 120" role="img" aria-label="Pulso, compañero de EnfermiCambio">
      <path className="pulse-aura" d="M23 72C13 50 29 23 55 17c25-6 50 9 57 33 7 25-8 50-32 58-24 8-47-5-57-36Z" />
      <path className="pulse-body" d="M26 69c-5-24 12-45 36-47 23-2 43 15 44 38 2 24-15 44-39 46-22 2-36-10-41-37Z" />
      <path className="pulse-shade" d="M73 24c18 5 31 21 32 39 1 19-11 36-29 41 8-12 12-27 9-43-2-15-6-27-12-37Z" />
      <path className="pulse-arm left" d="M31 61c-9 0-14 6-16 15" />
      <path className="pulse-arm right" d="M99 58c8-3 14 1 18 8" />
      <path className="pulse-leg left" d="M49 100c-1 7-4 10-10 13" />
      <path className="pulse-leg right" d="M78 101c2 7 6 10 12 11" />
      <ellipse className="pulse-eye left" cx="51" cy="57" rx="4" ry="5" />
      <ellipse className="pulse-eye right" cx="76" cy="55" rx="4" ry="5" />
      <path className="pulse-mouth" d="M54 73c7 6 15 5 21-1" />
      <path className="pulse-mark" d="M38 85h9l4-8 7 15 7-13 4 6h12" />
      <circle className="pulse-spark one" cx="20" cy="32" r="3" />
      <circle className="pulse-spark two" cx="104" cy="25" r="2" />
    </svg>
    {!compact && <p><b>Pulso</b><span>{message || COPY[state] || COPY.ready}</span></p>}
  </div>
}
