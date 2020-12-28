CREATE OR REPLACE FUNCTION inventory."matchIngredientIngredient"(ingredients jsonb, ingredientIds integer[]) RETURNS
SETOF crm."customerData" LANGUAGE plpgsql STABLE AS $function$

DECLARE
ingredient_i record;
ingredient record;
result jsonb;
arr jsonb := '[]';
matched_ingredient jsonb;

BEGIN
  IF ingredientIds IS NOT NULL THEN
    FOR ingredient_i IN 
      SELECT name, id FROM ingredient.ingredient 
      WHERE name IS NOT NULL 
      AND id = ANY(ingredientIds) LOOP

      SELECT * FROM jsonb_array_elements(ingredients) AS found_ingredient
      WHERE (found_ingredient ->> 'ingredientName')::text = ingredient_i.name 
      into matched_ingredient;

      IF matched_ingredient IS NOT NULL THEN arr := arr || jsonb_build_object(
          'ingredient',
          matched_ingredient,
          'ingredientId',
          ingredient_i.id
        ); 
      END IF;
    END LOOP;
  ELSE 
    FOR ingredient_i IN 
      SELECT name, id FROM ingredient.ingredient 
      WHERE name IS NOT NULL 
    LOOP

      SELECT * FROM jsonb_array_elements(ingredients) AS found_ingredient
      WHERE (found_ingredient ->> 'ingredientName')::text = ingredient_i.name 
      into matched_ingredient;

      IF matched_ingredient IS NOT NULL THEN arr := arr || jsonb_build_object(
          'ingredient',
          matched_ingredient,
          'ingredientId',
          ingredient_i.id
        ); 
      END IF;
    END LOOP;

  END IF;

result := jsonb_build_object('matchIngredientIngredient', arr);

RETURN QUERY
  SELECT 
    1 AS id,
    result AS data;
END;
$function$
