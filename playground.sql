-- convert a quantity from one unit to another unit
CREATE OR REPLACE FUNCTION inventory.unit_converter(
  quantity numeric,
  unit text,
  rule record
) 
RETURNS jsonb
LANGUAGE plpgsql STABLE AS
$$

DECLARE

converted_value numeric := 0::numeric;
result jsonb := '{}'::jsonb;
new_rule record;

BEGIN

  converted_value := (quantity)::numeric * (rule.factor)::numeric; -- equivalent quantity in rule.output_unit
  -- if rule.output_unit = unit then build result
  -- if the quantity is in kg and we want in crate
  -- there is a rule for crate to kg so this if block will run for that
  IF rule.output_unit = unit THEN

    result := 
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
  ELSEIF unit = rule.input_unit THEN
    converted_value := (converted_value)::numeric / (rule.factor)::numeric; -- equivalent quantity in rule.output_unit

    result := 
      jsonb_build_object(
        rule.input_unit, 
        jsonb_build_object(
          'factor', 
          (rule.factor)::numeric / (rule.factor)::numeric,
          /* 'unitConversionIdUsed', */ 
          /* rule.id */
          'error', 
          NULL,
          'returnQuantity',
          converted_value
        )
      );

  ELSE
    -- here the quantity is in g and we want the output unit in oz
    -- there is a rule for kg to g (output_unit = unit)

    -- we pick either g -> oz rule or...
    -- oz -> g rule
    
    SELECT 
      id, 
      "inputUnitName" input_unit, 
      "outputUnitName" output_unit, 
      "conversionFactor" factor, 
      "bulkDensity" bulk_density
      FROM master."unitConversion" 
      WHERE "outputUnitName" = unit AND "inputUnitName" = rule.output_unit INTO new_rule; -- output_unit is always canonical (for custom or standard)

    RAISE INFO '1. rule found in playground: % -> %', new_rule.input_unit, new_rule.output_unit;

    IF new_rule IS NULL THEN
      -- else we want to reverse our query and look for a rule whose...
      -- input_unit is unit and output_unit is rule.output_unit
      -- so we are looking for a rule kg -> g
      -- in this case we can do quantity * this_rule.factor

      SELECT 
        id, 
        "inputUnitName" input_unit, 
        "outputUnitName" output_unit, 
        "conversionFactor" factor, 
        "bulkDensity" bulk_density
        FROM master."unitConversion" 
        WHERE "outputUnitName" = rule.output_unit AND "inputUnitName" = unit INTO new_rule; -- output_unit is always canonical (for custom or standard)

      RAISE INFO '2. rule found in playground: % -> %', new_rule.input_unit, new_rule.output_unit;

      IF new_rule IS NULL THEN
        -- create an error msg that no rule is found for this conversion
        result := 
          jsonb_build_object(
            rule.input_unit, 
            jsonb_build_object(
              'error', 
              format('No rule is defined: %s -> %s', unit, rule.output_unit)
            )
          );
      ELSE
        -- in this case we can do quantity * this_rule.factor
        result := 
          jsonb_build_object(
            rule.input_unit, 
            jsonb_build_object(
              'factor', 
              (new_rule.factor)::numeric * (rule.factor)::numeric,
              /* 'unitConversionIdUsed', */ 
              /* rule.id */
              'error', 
              NULL,
              'returnQuantity',
              (converted_value)::numeric * (new_rule.factor)::numeric
            )
          );
      END IF;

    ELSE
      -- in this case, we can do quantity / this_rule.factor
      result := 
        jsonb_build_object(
          rule.input_unit, 
          jsonb_build_object(
            'factors_used', 
            (new_rule.factor)::numeric / (rule.factor)::numeric,
            /* 'unitConversionIdUsed', */ 
            /* rule.id */
            'error', 
            NULL,
            'returnQuantity',
            (converted_value)::numeric / (new_rule.factor)::numeric
          )
        );

    END IF;
  END IF;

  RETURN result;
END;
$$
