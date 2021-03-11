/* https://stackoverflow.com/a/64628819/9570381 */

CREATE or replace FUNCTION public.json_to_array(json) RETURNS text[] AS $f$
  SELECT coalesce(array_agg(x), 
    CASE WHEN $1 is null THEN null ELSE ARRAY[]::text[] END)
  FROM json_array_elements_text($1) t(x);
$f$ LANGUAGE sql IMMUTABLE;
