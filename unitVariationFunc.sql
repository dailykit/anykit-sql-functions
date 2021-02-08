/* -> create `unitVariationFunc` sql function */
/*     @params: tableName text, quantity numeric, unit text, bulkDensity numeric default 1, unitTo text default 'null' */
/*     @returns: json{custom: {[unitName]: value}, standard: {[unitName]: value}} */

CREATE OR REPLACE FUNCTION inventory."testFunc"(tableName text, quantity numeric, unit text, bulkDensity numeric default 1, unitTo text default 'null') 
RETURNS SETOF crm."customerData" 
LANGUAGE plpgsql STABLE AS $function$ 
DECLARE 
result jsonb;
definitions jsonb := $${"kg":{"name":{"abbr":"kg","singular":"Kilogram","plural":"Kilograms"},"base":"g","factor":1000},
                        "g":{"name":{"abbr":"g","singular":"Gram","plural":"Grams"},"base":"g","factor":1},
                        "mg":{"name":{"abbr":"mg","singular":"Miligram","plural":"MiliGrams"},"base":"g","factor":0.001},
                        "oz":{"name":{"abbr":"oz","singular":"Ounce","plural":"Ounces"},"base":"g","factor":28.3495},
                        "l":{"name":{"abbr":"l","singular":"Litre","plural":"Litres"},"base":"ml","factor":1000,"bulkDensity":1},
                        "ml":{"name":{"abbr":"ml","singular":"Millilitre","plural":"Millilitres"},"base":"ml","factor":1,"bulkDensity":1}
                        }$$;
known_units text[] := '{kg, g, mg, oz, l, ml}';

BEGIN  

  -- 1. Figure out how to create and check known units --done
  -- 2. Check if @param unit is in known units, return error if not! --done
  IF unit = ANY(known_units) THEN
  -- 3. convert definitions from json to json in postgre --done
  -- 4. loop through available definition and create the result jsonb
  -- 5. return result as data --done
    result := '{"message": "reached the else land!"}'::jsonb;
  ELSE
    result := '{"error": "invalid unit provided!"}'::jsonb;
  END IF;
    


RETURN QUERY
SELECT
  1 AS id,
  result as data;
END;

$function$

