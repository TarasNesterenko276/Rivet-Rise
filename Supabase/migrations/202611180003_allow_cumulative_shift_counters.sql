-- These counters accumulate across the entire shift, while floors stores only the
-- tallest tower reached. They cannot be bounded by the best tower height.
alter table public.rivet_shifts
  drop constraint if exists rivet_shifts_check,
  drop constraint if exists rivet_shifts_check1,
  drop constraint if exists rivet_shifts_check2;
