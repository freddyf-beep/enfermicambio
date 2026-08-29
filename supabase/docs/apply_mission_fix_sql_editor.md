# Aplicar el fix de `evaluate_missions` desde el SQL Editor

Este archivo existe para aplicar la corrección sin depender de credenciales de
conexión Postgres. Solo reemplaza una función y no cambia datos.

## Pasos

1. Abre el dashboard de Supabase y entra a tu proyecto
   `bweynxdzovnbcjwgddar`.
2. Ve a **SQL Editor** y crea una consulta nueva.
3. Pega **todo el contenido** de
   [`supabase/migrations/20260827100001_fix_evaluate_missions_ambiguity.sql`](../../migrations/20260827100001_fix_evaluate_missions_ambiguity.sql).
   El archivo ya incluye `drop function if exists ...` al inicio porque la
   firma cambia la columna de salida a `out_mission_id`.
4. Ejecuta. Si aparece la advertencia de operación destructiva, confirma con
   **Run query** (solo reemplaza la función, no toca datos). Debe mostrar
   "Success".
5. Pega y ejecuta
   [`supabase/scripts/mission_close_day_smoke_test.sql`](../../scripts/mission_close_day_smoke_test.sql).
   Busca en los mensajes `evaluate_missions OK` y el conteo de rachas.
6. Avísame o invoca `close_day` para la fecha de hoy; la PWA en `#/game`
   dejará de mostrar rachas en cero.

## Notas

- El SQL es idempotente (`create or replace function`); se puede re-ejecutar.
- No borra ni modifica datos: solo redefine la función evaluadora.
- Después de aplicar, el historial de migraciones local sigue divergiendo del
  remoto; la reconciliación completa queda documentada en
  `migration_history_reconciliation.md`.
