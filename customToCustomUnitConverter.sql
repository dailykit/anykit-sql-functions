-- customToCustomUnitConverter sql function

CREATE OR REPLACE 
FUNCTION inventory."customToCustomUnitConverter"(quantity numeric, unit text, bulkDensity numeric default 1, unitTo text default null) 
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
    WHERE "inputUnitName" = unitTo
    into to_custom_rule;

  SELECT "inputUnitName" input_unit, "outputUnitName" output_unit, "conversionFactor" conversion_factor 
    FROM master."unitConversion" 
    WHERE "inputUnitName" = unit
    into from_custom_rule;

  IF to_custom_rule IS NULL THEN
    proceed := 'to_unit';
  ELSEIF from_custom_rule IS NULL THEN
    proceed := 'from_unit';
  END IF;

  IF proceed IS NULL THEN

    SELECT data->'result'->'custom'->unit
      FROM inventory."unitVariationFunc"('tablename', quantity, unit, -1, to_custom_rule.output_unit::text) 
      INTO from_in_standard;

    SELECT data 
      FROM inventory."standardToCustomUnitConverter"((from_in_standard->'equivalentValue')::numeric, (from_in_standard->>'toUnitName')::text, -1, unitTo)
      INTO result;

    result := jsonb_build_object(
      'error', 
      'null'::jsonb,
      'result',
      jsonb_build_object(
        'value',
        quantity,
        'toUnitName',
        unitTo,
        'fromUnitName',
        unit,
        'equivalentValue',
        (result->'result'->'equivalentValue')::numeric
      )
    );

  ELSEIF proceed = 'to_unit' THEN
    result := 
      format('{"error": "no custom unit is defined with the name: %s, create a conversion rule in the master.\"unitConversion\" table."}', unitTo::text)::jsonb;
  ELSEIF proceed = 'from_unit' THEN
    result := 
      format('{"error": "no custom unit is defined with the name: %s, create a conversion rule in the master.\"unitConversion\" table."}', unit::text)::jsonb;
  END IF;

  RETURN QUERY
  SELECT
    1 AS id,
    result as data;

END;
$function$

