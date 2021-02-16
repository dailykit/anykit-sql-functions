-- standardToCustomUnitConverter sql function

CREATE OR REPLACE 
FUNCTION inventory."standardToCustomUnitConverter"(quantity numeric, unit text, bulkDensity numeric default 1, unitTo text default null) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$ 
DECLARE 

result jsonb := '{"error": null, "result": null}'::jsonb;
custom_rule record;
converted_standard jsonb;

BEGIN  
  -- unitTo is a custom rule in master."unitConversion"
  SELECT "inputUnitName" input_unit, "outputUnitName" output_unit, "conversionFactor" conversion_factor 
    FROM master."unitConversion" 
    WHERE "inputUnitName" = unitTo
    into custom_rule;

  IF custom_rule IS NOT NULL THEN
    SELECT data FROM inventory."unitVariationFunc"('tablename', quantity, unit, -1, custom_rule.output_unit) into converted_standard;

    result := jsonb_build_object(
      'error', 
      'null'::jsonb, 
      'result', 
      jsonb_build_object(
        'fromUnitName', 
        unit, 
        'toUnitName', 
        unitTo,
        'value',
        quantity,
        'equivalentValue',
        (converted_standard->'result'->'standard'->custom_rule.output_unit->>'equivalentValue')::numeric / custom_rule.conversion_factor
    ));
  ELSE
    -- costruct an error msg
    result := 
      format('{"error": "no custom unit is defined with the name: %s, create a conversion rule in the master.\"unitConversion\" table."}', unitTo)::jsonb;
  END IF;

  RETURN QUERY
  SELECT
    1 AS id,
    result as data;

END;

$function$

