/*

  This function is called only when:

    1. from_unit is not null and IN standard_units_definition.
    2. to_unit is NOT IN standard_units_definition AND IS NOT ''.

*/

-- standard_to_custom_unit_converter sql function
CREATE OR REPLACE 
FUNCTION inventory.standard_to_custom_unit_converter(
  quantity               numeric,
  from_unit              text,
  from_bulk_density      numeric,
  to_unit                text,
  to_unit_bulk_density   numeric,
  unit_conversion_id     integer
) 
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
    WHERE id = unit_conversion_id
    into custom_rule;

  IF custom_rule IS NOT NULL THEN
    SELECT data FROM inventory.standard_to_standard_unit_converter(
      quantity, 
      from_unit, 
      from_bulk_density,
      custom_rule.output_unit, 
      to_unit_bulk_density,
      '', -- schemaname
      '', -- tablename
      0 -- entity id
    ) into converted_standard;

    result := jsonb_build_object(
      'error', 
      'null'::jsonb, 
      'result', 
      jsonb_build_object(
        'fromUnitName', 
        from_unit, 
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
      format(
        '{"error": "no custom unit is defined with the id: %s and name: %s, create a conversion rule in the master.\"unitConversion\" table."}', 
        unit_conversion_id,
        to_unit
      )::jsonb;

  END IF;

  RETURN QUERY
  SELECT
    1 AS id,
    result as data;

END;

$function$

