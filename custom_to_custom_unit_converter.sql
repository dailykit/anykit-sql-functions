/*

  This function is called only when:

    1. from_unit is not null and NOT IN standard_units_definition.
    2. to_unit is NOT '' AND NOT IN standard_units_definition.

*/

-- custom_to_custom_unit_converter sql function
CREATE OR REPLACE
FUNCTION inventory.custom_to_custom_unit_converter(
  quantity              numeric,
  from_unit             text,
  from_bulk_density     numeric,
  to_unit               text,
  to_unit_bulk_density  numeric,
  from_unit_id          integer,
  to_unit_id            integer
) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$ 
DECLARE 

from_custom_rule record;
to_custom_rule record;
result jsonb := '{"error": null, "result": null}'::jsonb;
proceed text := NULL;
from_in_standard jsonb;

BEGIN  

  SELECT "inputUnitName" input_unit, "outputUnitName" output_unit, "conversionFactor" conversion_factor 
    FROM master."unitConversion" 
    WHERE id = to_unit_id
    into to_custom_rule;

  SELECT "inputUnitName" input_unit, "outputUnitName" output_unit, "conversionFactor" conversion_factor 
    FROM master."unitConversion" 
    WHERE id = from_unit_id
    into from_custom_rule;

  IF to_custom_rule IS NULL THEN
    proceed := 'to_unit';
  ELSEIF from_custom_rule IS NULL THEN
    proceed := 'from_unit';
  END IF;

  IF proceed IS NULL THEN
    SELECT data->'result'->'custom'->from_custom_rule.input_unit
      FROM inventory.custom_to_standard_unit_converter(
        quantity, 
        from_custom_rule.input_unit, 
        from_bulk_density,
        to_custom_rule.output_unit::text, 
        to_unit_bulk_density,
        from_unit_id,
        '',
        '',
        0
      ) INTO from_in_standard;

    SELECT data 
      FROM inventory.standard_to_custom_unit_converter(
        (from_in_standard->'equivalentValue')::numeric, 
        (from_in_standard->>'toUnitName')::text, 
        from_bulk_density,
        to_unit,
        to_unit_bulk_density,
        to_unit_id
      ) INTO result;

    result := jsonb_build_object(
      'error', 
      'null'::jsonb,
      'result',
      jsonb_build_object(
        'value',
        quantity,
        'toUnitName',
        to_unit,
        'fromUnitName',
        from_unit,
        'equivalentValue',
        (result->'result'->'equivalentValue')::numeric
      )
    );

  ELSEIF proceed = 'to_unit' THEN

    result := 
      format(
        '{"error": "no custom unit is defined with the id: %s for argument to_unit, create a conversion rule in the master.\"unitConversion\" table."}', 
        to_unit_id
      )::jsonb;

  ELSEIF proceed = 'from_unit' THEN

    result := 
      format(
        '{"error": "no custom unit is defined with the id: %s for argument from_unit, create a conversion rule in the master.\"unitConversion\" table."}', 
        from_unit_id
      )::jsonb;

  END IF;

  RETURN QUERY
  SELECT
    1 AS id,
    result as data;

END;
$function$

