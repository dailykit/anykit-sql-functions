/* 
 
 runs on sachetItem create/update
 runs on recipeHub call with sachets
 
 input Array<{id: sachetId, quantity: "", ingredientName: "", processingName: ""}>
 input Array<int> optional supplierItem ids
 
 output {
 id: 1,
 data: {
 sachetSachetItemMatches: Array<{sachet<payload>, sachetItemId, isProcessingExactMatch}>
 }
 }
 
 same as matchSachetSupplierItem but matches the sachet quantity not the supplierItem.unitSize
 */
CREATE OR REPLACE FUNCTION inventory."matchSachetSachetItem"(sachets jsonb, supplierItemInputs integer []) RETURNS SETOF crm."customerData" LANGUAGE plpgsql STABLE AS $function$
DECLARE supplier_item record;
sachet record;
result jsonb;
arr jsonb := '[]';
matched_sachet jsonb;
BEGIN IF supplierItemInputs IS NOT NULL THEN FOR supplier_item IN
SELECT "supplierItem".id,
  "supplierItem"."name",
  "processingName",
  "bulkItem".id "processingId",
  "sachetItem"."unitSize",
  "sachetItem"."unit"
FROM inventory."supplierItem"
  LEFT JOIN inventory."bulkItem" ON "supplierItem"."id" = "bulkItem"."supplierItemId"
  LEFT JOIN inventory."sachetItem" ON "sachetItem"."bulkItemId" = "bulkItem"."id"
WHERE "sachetItem"."unitSize" IS NOT NULL
  AND "supplierItem".id = ANY (supplierItemInputs) LOOP
SELECT *
FROM jsonb_array_elements(sachets) AS found_sachet
WHERE (found_sachet->>'quantity')::int = supplier_item."unitSize"
  AND (found_sachet->>'processingName') = supplier_item."processingName"
  AND (found_sachet->>'ingredientName') = supplier_item.name INTO matched_sachet;
IF matched_sachet IS NOT NULL THEN arr := arr || jsonb_build_object(
  'sachet',
  matched_sachet,
  'supplierItemId',
  supplier_item.id,
  'supplierItemUnit',
  supplier_item.unit,
  'isProcessingExactMatch',
  true
);
END IF;
END LOOP;
ELSE FOR supplier_item IN
SELECT "supplierItem".id,
  "supplierItem"."name",
  "processingName",
  "bulkItem".id "processingId",
  "sachetItem"."unitSize",
  "sachetItem"."unit"
FROM inventory."supplierItem"
  LEFT JOIN inventory."bulkItem" ON "supplierItem"."id" = "bulkItem"."supplierItemId"
  LEFT JOIN inventory."sachetItem" ON "sachetItem"."bulkItemId" = "bulkItem"."id"
WHERE "sachetItem"."unitSize" IS NOT NULL
  AND "processingName" IS NOT NULL LOOP
SELECT *
FROM jsonb_array_elements(sachets) AS found_sachet
WHERE (found_sachet->>'quantity')::int = supplier_item."unitSize"
  AND (found_sachet->>'processingName') = supplier_item."processingName"
  AND (found_sachet->>'ingredientName') = supplier_item.name INTO matched_sachet;
IF matched_sachet IS NOT NULL THEN arr := arr || jsonb_build_object(
  'sachet',
  matched_sachet,
  'supplierItemId',
  supplier_item.id,
  'supplierItemUnit',
  supplier_item.unit,
  'isProcessingExactMatch',
  true
);
END IF;
END LOOP;
END IF;
result := jsonb_build_object('sachetSachetItemMatches', arr);
RETURN QUERY
SELECT 1 AS id,
  result as data;
END;
$function$