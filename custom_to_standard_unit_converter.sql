/* 
  Observations:
    - to convert from custom to standard
      quantity * fromUnitFactor / toUnitFactor
      example: 1 crate -> 10kgs (custom definition)
               1 crate -> ?grams
               Now, quantity = 1, fromUnitFactor is 10 (10kgs) , toFactorUnit is 1/1000 (standard defnition)
               so, 1 * 10 / 1/1000 gives 10000 grams
    - to convert from standard to custom
      same formula, quantity * fromUnitFactor / toUnitFactor
      example: 100 grams -> ?crate(s)
               Now, quantity is 100, fromUnitFactor is 1/1000 (standard definition), toUnitFactor is 10.
               so, 1 * 1/1000 / 10 gives 0.01 crates
    - to convert from custom to custom
      the same formula works for custom to custom rules where the toFactor has same standard unit

    - SELECT '{"name": "siddhant"}'::jsonb->'name'->'some'->'twosome' as main, is valid sql
*/

/*

  This function is called only when:

    1. from_unit is not null and NOT IN standard_units_definition.
    2. to_unit is '' or IN standard_units_definition.

*/

CREATE OR REPLACE FUNCTION inventory.custom_to_standard_unit_converter(
  quantity               numeric,
  from_unit              text,
  from_bulk_density      numeric,
  to_unit                text,
  to_unit_bulk_density   numeric,
  unit_conversion_id     integer,
  schemaname             text,
  tablename              text,
  entity_id              integer
)
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql STABLE AS $$

DECLARE

result jsonb;
custom_conversions jsonb;
standard_conversions jsonb;
custom_unit_definition record;

BEGIN 

  SELECT "inputUnitName" input_unit, "outputUnitName" output_unit, "conversionFactor" conversion_factor 
    FROM master."unitConversion" 
    WHERE id = unit_conversion_id
    into custom_unit_definition;

  If custom_unit_definition IS NOT NULL THEN
    custom_conversions := 
      jsonb_build_object(
        custom_unit_definition.input_unit, 
        jsonb_build_object(
          'value', 
          quantity, 
          'toUnitName', 
          custom_unit_definition.output_unit,
          'fromUnitName',
          custom_unit_definition.input_unit,
          'equivalentValue',
          quantity * custom_unit_definition.conversion_factor
        )
      );

    SELECT data->'result'
      FROM inventory.standard_to_standard_unit_converter(
        quantity * custom_unit_definition.conversion_factor, 
        custom_unit_definition.output_unit, 
        from_bulk_density, 
        to_unit, 
        to_unit_bulk_density,
        schemaname,
        tablename,
        entity_id,
        'all'
      ) INTO standard_conversions;

  ELSE 

    result := 
      format(
        '{"error": "no custom unit is defined with the id: %s and name: %s, create a conversion rule in the master.\"unitConversion\" table."}', 
        unit_conversion_id,
        from_unit
      )::jsonb;

  END IF;

  result :=
    jsonb_build_object(
      'error',
      result->>'error',
      'result', 
      jsonb_build_object(
        'custom', 
        custom_conversions, 
        'others', 
        standard_conversions
      )
    );

  RETURN QUERY
  SELECT
    1 as id,
    result as data;
END;
$$
