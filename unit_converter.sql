/*
  @param input jsonb 
  {
      "givenQuantity" : "100", if not given, default is 1
      "givenUnit*" : "kg",
      "returnUnits" : [crate, jar],
      "appliedUnitConversions" : [3,4,5,6,7,8],
      "tablename": "",
      "schemaname": "",
  }
*/
CREATE OR REPLACE 
FUNCTION inventory.unit_converter(
  quantity numeric,
  unit text,
  return_units text[],
  applied_custom_unit_conversion_ids integer[]
) 
RETURNS SETOF crm."customerData"
LANGUAGE plpgsql
STABLE AS $$

DECLARE 

  result jsonb := '{}'::jsonb;
  conversions jsonb := '{}'::jsonb; -- keys in this object will be the entries of return_units
  converted_value numeric := 0; -- 0 means there maybe some error message
  intermediate_rule record;
  rule record;

conversion_rule record;

BEGIN

  -- select rules from master."unitConversion" table
  -- rules are records whose input_unit is in return_units
  FOR rule IN 
    SELECT 
      id, 
      "inputUnitName" input_unit, 
      "outputUnitName" output_unit, 
      "conversionFactor" factor, 
      "bulkDensity" bulk_density
      FROM master."unitConversion" 
      WHERE (id = ANY(applied_custom_unit_conversion_ids) AND "inputUnitName" = ANY(return_units)) 
      OR ("isCanonical" IS TRUE AND "inputUnitName" = ANY(return_units)) 
  LOOP
    -- for each rule
    -- we want to convert the quantity in current unit to the quantity in mentioned unit in this rule
    
    -- convert 100 kg to crate
    -- we need a rule 1 kg = 0.1 crate
    -- so we can do 100 * 0.1 = 10 crate

    -- what if we have two rules:
    -- g -> crate factor 0.0001
    -- kg -> g factor 1000

    -- convert from @param unit to output_unit of this rule. 
    converted_value := (quantity)::numeric * (rule.factor)::numeric; -- equivalent quantity in rule.output_unit

    -- if rule.output_unit = unit then build result
    IF rule.output_unit = unit THEN
      conversions := conversions || 
        jsonb_build_object(
          rule.input_unit, 
          jsonb_build_object(
            'factor', 
            (rule.factor)::numeric,
            /* 'unitConversionIdUsed', */ 
            /* rule.id */
            'error', 
            NULL,
            'returnQuantity',
            converted_value
          )
        );
      ELSE
      -- else call this function recursively to convert from rule.output_unit to unit

      converted_value := inventory.unit_converter(
        converted_value,
        rule.output_unit,
        format('{%s}', unit)
        applied_custom_unit_conversion_ids integer[]
      );
      conversions := conversions || 
        jsonb_build_object(
          rule.input_unit, 
          jsonb_build_object(
            'factor', 
            rule.factor, 
            'unitConversionIdUsed', 
            jsonb_build_array(rule.id), 
            'error', 
            format('There is no rule for converting from %s to %s', rule.output_unit, unit)
          )
        );
    END IF;

  END LOOP;

  result := jsonb_build_object(
    'givenUnit', unit, 
    'givenQuantity', quantity, 
    'returnUnits', conversions 
  );

RETURN QUERY 
SELECT 1 as id, result as data;

END;
$$




