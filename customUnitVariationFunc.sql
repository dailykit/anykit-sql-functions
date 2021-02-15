/* 
  pl/pgsql function that returns equivalent quantities in standard units from a custom unit.
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

  ### Things I am afraid of:

  1. How would I handle custom to custom unit conversion? (crate to bags)?
  2. What if they define rules like these:
    1 crate -> 10kgs
    1 crate -> 10 bags
    10 bags -> 1000 grams.
*/

/* How this function will be called?
   -> This will be called inside unitVariationFunc if the unit is not in standard definitions
*/

-- TODO: convert from standard to custom unit;

CREATE OR REPLACE FUNCTION inventory."customUnitVariationFunc"(quantity numeric, customUnit text, toUnit text default null)
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
    WHERE "inputUnitName" = customUnit
    into custom_unit_definition;

  If custom_unit_definition IS NOT NULL THEN
    custom_conversions := 
        jsonb_build_object(customUnit, jsonb_build_object(
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

    IF toUnit IS NULL THEN
      SELECT data->'result'->'standard' FROM inventory."unitVariationFunc"('tablename', quantity, custom_unit_definition.output_unit) into standard_conversions;
--    ELSE 
      -- TODO: convert only to toUnit

    END IF;

  ELSE 

    result := 
      format('{"error": "no custom unit is defined with the name: %s, create a conversion rule in the master.\"unitConversion\" table."}', customUnit)::jsonb;

  END IF;

  result :=
    jsonb_build_object(
      'error',
      result->>'error',
      'result', 
      jsonb_build_object(
        'custom', 
        custom_conversions, 
        'standard', 
        standard_conversions
      )
    );

  RETURN QUERY
  SELECT
    1 as id,
    result as data;
END
$$
