export function Spinner({ label }: { label?: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-10 text-parchment-300">
      <span
        aria-hidden
        className="h-8 w-8 animate-spin rounded-full border-2 border-gold-500/30 border-t-gold-400"
      />
      {label && <span className="font-display text-xs uppercase tracking-widest">{label}</span>}
    </div>
  );
}
