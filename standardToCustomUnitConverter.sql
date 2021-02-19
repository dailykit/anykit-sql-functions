-- standardToCustomUnitConverter sql function

CREATE OR REPLACE 
-- @param unit is always a standard unit
-- @param unit_to_id is id of a custom rule in master."unitConversion"
FUNCTION inventory."standardToCustomUnitConverter"(quantity numeric, unit text, bulkDensity numeric default 1, unit_to_id numeric default null) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $function$ 
DECLARE 

result jsonb := '{"error": null, "result": null}'::jsonb;
custom_rule record;
converted_standard jsonb;

BEGIN  
  -- unit_to_id is the id of a custom rule in master."unitConversion"
  SELECT "inputUnitName" input_unit, "outputUnitName" output_unit, "conversionFactor" conversion_factor 
    FROM master."unitConversion" 
    WHERE id = unit_to_id
    into custom_rule;

  IF custom_rule IS NOT NULL THEN
    SELECT data FROM inventory."unitVariationFunc"(quantity, unit, (-1)::numeric, custom_rule.output_unit, -1) into converted_standard;

    result := jsonb_build_object(
      'error', 
      'null'::jsonb, 
      'result', 
      jsonb_build_object(
        'fromUnitName', 
        unit, 
        'toUnitName', 
        custom_rule.input_unit,
        'value',
        quantity,
        'equivalentValue',
        (converted_standard->'result'->'standard'->custom_rule.output_unit->>'equivalentValue')::numeric / custom_rule.conversion_factor
    ));
  ELSE
    -- costruct an error msg
    result := 
      format('{"error": "no custom unit is defined with the id: %s, create a conversion rule in the master.\"unitConversion\" table."}', unit_to_id)::jsonb;
  END IF;

  RETURN QUERY
  SELECT
    1 AS id,
    result as data;

END;

$function$

