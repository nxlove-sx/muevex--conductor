-- ============================================================================
-- MUEVEX — MIGRACIÓN DE INTEGRACIÓN ENTRE CLIENTE Y CONDUCTOR (v2)
-- Ejecutar en Supabase → SQL Editor después de migracion_conductor.sql
-- 100% idempotente: se puede volver a ejecutar sin errores.
-- Convierte el estado del servicio a los 7 estados canónicos de la plataforma:
--   solicitado, aceptado, en_recogida, en_curso, completado,
--   cancelado_cliente, cancelado_conductor
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) SERVICIOS: estado canónico (TEXT + CHECK) y columnas del spec
-- ---------------------------------------------------------------------------
-- Las políticas RLS de services dependen de la columna status:
-- se eliminan antes de alterar el tipo y se recrean completas al final.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies
           WHERE schemaname = 'public' AND tablename = 'services'
  LOOP
    EXECUTE format('DROP POLICY %I ON public.services', r.policyname);
  END LOOP;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_attribute a ON a.attrelid = 'services'::regclass
      AND a.attname = 'status' AND a.atttypid = t.oid
    WHERE t.typtype = 'e'
  ) THEN
    ALTER TABLE public.services ALTER COLUMN status DROP DEFAULT;
    ALTER TABLE public.services ALTER COLUMN status TYPE text USING (
      CASE lower(status::text)
        WHEN 'requested'            THEN 'solicitado'
        WHEN 'searching_driver'     THEN 'solicitado'
        WHEN 'driver_accepted'      THEN 'aceptado'
        WHEN 'driver_on_way'        THEN 'aceptado'
        WHEN 'driver_arrived'       THEN 'en_recogida'
        WHEN 'loading'              THEN 'en_recogida'
        WHEN 'in_transit'           THEN 'en_curso'
        WHEN 'arrived_destination'  THEN 'en_curso'
        WHEN 'delivered'            THEN 'completado'
        WHEN 'completed'            THEN 'completado'
        WHEN 'cancelled'            THEN 'cancelado_conductor'
        ELSE 'solicitado'
      END
    );
  END IF;
END $$;

ALTER TABLE public.services ALTER COLUMN status SET DEFAULT 'solicitado';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'services'::regclass AND conname = 'services_status_check'
  ) THEN
    ALTER TABLE public.services ADD CONSTRAINT services_status_check
      CHECK (status IN ('solicitado','aceptado','en_recogida','en_curso','completado','cancelado_cliente','cancelado_conductor'));
  END IF;
END $$;

-- Columnas del spec 52 (ninguna destructiva)
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS load_description TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS load_weight_kg NUMERIC(10,2) DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS floors INTEGER DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS loading_help BOOLEAN DEFAULT FALSE;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS estimated_price NUMERIC(10,2);
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS final_price NUMERIC(10,2);
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(10,2) DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS driver_earnings NUMERIC(10,2) DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS photos TEXT[] DEFAULT '{}';

-- Rellenar coherentemente desde columnas legacy
UPDATE public.services SET
  estimated_price = COALESCE(estimated_price, price_base, 0),
  duration_minutes = COALESCE(duration_minutes, estimated_time_min, 0),
  load_description = COALESCE(load_description, description),
  floors = COALESCE(floors, 0),
  loading_help = COALESCE(loading_help, needs_help, FALSE),
  load_weight_kg = COALESCE(load_weight_kg, 0)
WHERE estimated_price IS NULL OR load_description IS NULL;

UPDATE public.services SET
  driver_earnings = COALESCE(estimated_price, price_base, 0) - COALESCE(platform_fee, 0),
  final_price = COALESCE(final_price, estimated_price, price_base)
WHERE status = 'completado';

-- ---------------------------------------------------------------------------
-- 2) FUNCION COMÚN DE NOTIFICACIÓN (evita duplicar SQL)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_user(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_message text,
  p_data jsonb DEFAULT '{}'
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, message, data)
  VALUES (p_user_id, p_type::notification_type_enum, p_title, p_message, p_data);
END $$;

-- ---------------------------------------------------------------------------
-- 3) RPC ACCEPT_SERVICE — aceptación atómica (spec 54)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_service(p_service_id uuid)
RETURNS SETOF public.services
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id uuid;
  v_origin      text;
BEGIN
  UPDATE public.services
     SET driver_id = auth.uid(),
         status = 'aceptado',
         accepted_at = NOW()
   WHERE id = p_service_id
     AND status = 'solicitado'
     AND driver_id IS NULL
 RETURNING customer_id, COALESCE(origin_name, 'tu destino') INTO v_customer_id, v_origin;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este servicio ya fue asignado a otro conductor.';
  END IF;

  PERFORM public.notify_user(
    v_customer_id, 'service_accepted',
    'Conductor asignado',
    'Un conductor aceptó tu solicitud de traslado.',
    jsonb_build_object('service_id', p_service_id)
  );

  RETURN QUERY SELECT * FROM public.services WHERE id = p_service_id;
END $$;

-- ---------------------------------------------------------------------------
-- 4) RPC UPDATE_SERVICE_STATUS — transiciones controladas (spec 50/60)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_service_status(p_service_id uuid, p_status text)
RETURNS SETOF public.services
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id uuid;
  v_est         numeric;
  v_fee         numeric;
BEGIN
  IF p_status NOT IN ('en_recogida','en_curso','completado', 'aceptado') THEN
    RAISE EXCEPTION 'Transición de estado no permitida.';
  END IF;

  IF p_status = 'en_recogida' THEN
    UPDATE public.services
       SET status = 'en_recogida'
     WHERE id = p_service_id AND driver_id = auth.uid() AND status = 'aceptado'
     RETURNING customer_id INTO v_customer_id;
  ELSIF p_status = 'en_curso' THEN
    UPDATE public.services
       SET status = 'en_curso', started_at = NOW()
     WHERE id = p_service_id AND driver_id = auth.uid() AND status = 'en_recogida'
     RETURNING customer_id INTO v_customer_id;
  ELSE -- 'completado'
    UPDATE public.services
       SET status = 'completado',
           completed_at = NOW(),
           final_price = COALESCE(estimated_price, price_base, 0),
           driver_earnings = COALESCE(estimated_price, price_base, 0)
                             - COALESCE(platform_fee, 0)
     WHERE id = p_service_id AND driver_id = auth.uid() AND status = 'en_curso'
     RETURNING customer_id, driver_earnings, platform_fee INTO v_customer_id, v_est, v_fee;

    IF FOUND THEN
      UPDATE public.driver_profiles
         SET total_services = total_services + 1
       WHERE user_id = auth.uid();
    END IF;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No puedes cambiar el estado de este servicio.';
  END IF;

  PERFORM public.notify_user(
    v_customer_id,
    CASE p_status
      WHEN 'en_recogida' THEN 'service_arrival'
      WHEN 'en_curso'    THEN 'service_started'
      ELSE 'service_completed'
    END,
    CASE p_status
      WHEN 'en_recogida' THEN 'Tu conductor llegó'
      WHEN 'en_curso'    THEN 'Tu servicio está en curso'
      ELSE 'Servicio completado'
    END,
    CASE p_status
      WHEN 'en_recogida' THEN 'Tu conductor ya está en el origen.'
      WHEN 'en_curso'    THEN 'Tu carga va en camino hacia el destino.'
      ELSE 'Servicio completado. Gracias por usar MUEVEX, cuenta con nosotros.'
    END,
    jsonb_build_object('service_id', p_service_id, 'status', p_status)
  );

  RETURN QUERY SELECT * FROM public.services WHERE id = p_service_id;
END $$;

-- ---------------------------------------------------------------------------
-- 5) RPC CANCEL_SERVICE (spec 61)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_service(p_service_id uuid, p_cancelled_by text)
RETURNS SETOF public.services
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_title text;
  v_message text;
  v_type text;
  v_new text;
BEGIN
  IF p_cancelled_by = 'cliente' THEN
    v_new := 'cancelado_cliente';
    UPDATE public.services
       SET status = v_new, driver_id = NULL
     WHERE id = p_service_id AND customer_id = auth.uid() AND status = 'solicitado'
     RETURNING customer_id INTO v_user_id;
    v_title := 'Servicio cancelado'; v_message := 'Cancelaste la solicitud.'; v_type := 'service_cancelled';
  ELSIF p_cancelled_by = 'conductor' THEN
    v_new := 'cancelado_conductor';
    UPDATE public.services
       SET status = v_new, driver_id = NULL
     WHERE id = p_service_id AND driver_id = auth.uid()
       AND status IN ('aceptado','en_recogida','en_curso')
     RETURNING customer_id INTO v_user_id;
    v_title := 'Tu conductor canceló'; v_message := 'El conductor canceló el servicio.'; v_type := 'service_cancelled_by_driver';
  ELSE
    RAISE EXCEPTION 'Origen de cancelación inválido.';
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No puedes cancelar este servicio en su estado actual.';
  END IF;

  IF p_cancelled_by = 'conductor' THEN
    PERFORM public.notify_user(v_user_id, v_type, v_title, v_message,
      jsonb_build_object('service_id', p_service_id));
  END IF;

  RETURN QUERY SELECT * FROM public.services WHERE id = p_service_id;
END $$;

-- ---------------------------------------------------------------------------
-- 6) TRIGGERS: promedio de calificación y aviso al conductor (spec 65)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.on_rating_inserted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_profiles_id uuid;
BEGIN
  SELECT id INTO v_driver_profiles_id
    FROM public.driver_profiles
   WHERE user_id = NEW.rated_id;

  IF FOUND THEN
    UPDATE public.driver_profiles
       SET rating = COALESCE((SELECT AVG(score)::numeric(3,2) FROM public.ratings WHERE rated_id = NEW.rated_id), 0),
           updated_at = NOW()
     WHERE id = v_driver_profiles_id;
  END IF;

  PERFORM public.notify_user(
    NEW.rated_id, 'new_rating',
    'Nueva calificación',
    'Un cliente te calificó con ' || NEW.score::text || ' estrellas.',
    jsonb_build_object('service_id', NEW.service_id, 'rating', NEW.score, 'comment', NEW.comment)
  );
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trig_on_rating ON public.ratings;
CREATE TRIGGER trig_on_rating
  AFTER INSERT ON public.ratings
  FOR EACH ROW EXECUTE FUNCTION public.on_rating_inserted();

-- ---------------------------------------------------------------------------
-- 7) STORAGE: buckets estandarizados del spec (62)
--    profiles/{user_id}/, vehicles/{driver_id}/, service-loads/{service_id}/
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES
    ('profiles',      'profiles',      TRUE, 5242880,  ARRAY['image/png','image/jpeg','image/webp','image/heic']),
    ('vehicles',      'vehicles',      TRUE, 5242880,  ARRAY['image/png','image/jpeg','image/webp','image/heic']),
    ('service-loads', 'service-loads', TRUE, 10485760, ARRAY['image/png','image/jpeg','image/webp','image/heic'])
  ON CONFLICT (id) DO NOTHING;
END $$;

-- Políticas de storage (idempotentes)
DROP POLICY IF EXISTS "profiles_upload_own" ON storage.objects;
CREATE POLICY "profiles_upload_own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "vehicles_upload_own" ON storage.objects;
CREATE POLICY "vehicles_upload_own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'vehicles' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "service_loads_upload_own" ON storage.objects;
CREATE POLICY "service_loads_upload_own" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'service-loads'
    AND EXISTS (
      SELECT 1 FROM public.services
      WHERE id::text = (storage.foldername(name))[1] AND customer_id = auth.uid()
    ));

DROP POLICY IF EXISTS "profiles_select_public" ON storage.objects;
CREATE POLICY "profiles_select_public" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN ('profiles','vehicles','service-loads'));

-- ---------------------------------------------------------------------------
-- 8) RLS: lectura de información del conductor para el cliente (spec 55)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "customers_read_assigned_driver" ON public.users;
CREATE POLICY "customers_read_assigned_driver" ON public.users FOR SELECT TO authenticated
  USING (role = 'driver'
    AND id IN (SELECT driver_id FROM public.services
               WHERE customer_id = auth.uid() AND driver_id IS NOT NULL));

DROP POLICY IF EXISTS "customers_read_assigned_profile" ON public.driver_profiles;
CREATE POLICY "customers_read_assigned_profile" ON public.driver_profiles FOR SELECT TO authenticated
  USING (user_id IN (SELECT driver_id FROM public.services
                     WHERE customer_id = auth.uid() AND driver_id IS NOT NULL));

DROP POLICY IF EXISTS "customers_read_assigned_vehicles" ON public.vehicles;
CREATE POLICY "customers_read_assigned_vehicles" ON public.vehicles FOR SELECT TO authenticated
  USING (driver_id IN (SELECT id FROM public.driver_profiles
                       WHERE user_id IN (SELECT driver_id FROM public.services
                                         WHERE customer_id = auth.uid() AND driver_id IS NOT NULL)));

-- Servicios: el cliente crea y ve los suyos; el conductor ve solicitudes/compatibles
DROP POLICY IF EXISTS "customers_insert_own_services" ON public.services;
CREATE POLICY "customers_insert_own_services" ON public.services FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "customers_select_own_services" ON public.services;
CREATE POLICY "customers_select_own_services" ON public.services FOR SELECT TO authenticated
  USING (customer_id = auth.uid());

-- Ajustar la política del conductor a los nuevos estados
DROP POLICY IF EXISTS "drivers_select_available_requests" ON public.services;
CREATE POLICY "drivers_select_available_requests" ON public.services FOR SELECT TO authenticated
  USING (
    driver_id = auth.uid()
    OR customer_id = auth.uid()
    OR (status = 'solicitado' AND driver_id IS NULL)
  );

-- Reconducir: el conductor actualiza solo sus servicios
DROP POLICY IF EXISTS "drivers_update_own_services" ON public.services;
CREATE POLICY "drivers_update_own_services" ON public.services FOR UPDATE TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- Calificaciones: el cliente califica servicios propios (spec 65)
DROP POLICY IF EXISTS "customers_insert_own_ratings" ON public.ratings;
CREATE POLICY "customers_insert_own_ratings" ON public.ratings FOR INSERT TO authenticated
  WITH CHECK (
    rater_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.services
                WHERE id = service_id AND customer_id = auth.uid())
  );

-- Pagos: el cliente registra el pago de su servicio
DROP POLICY IF EXISTS "customers_insert_payments" ON public.payments;
CREATE POLICY "customers_insert_payments" ON public.payments FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.services
            WHERE id = service_id AND customer_id = auth.uid())
  );

-- Notificaciones: solo propias
DROP POLICY IF EXISTS "notifications_insert_own" ON public.notifications;
CREATE POLICY "notifications_insert_own" ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Cliente: editar su propio servicio (para guardar fotos tras crearla)
DROP POLICY IF EXISTS "customers_update_own_services" ON public.services;
CREATE POLICY "customers_update_own_services" ON public.services FOR UPDATE TO authenticated
  USING (customer_id = auth.uid())
  WITH CHECK (customer_id = auth.uid());

-- Cliente: editar su perfil (users + customer_profiles)
DROP POLICY IF EXISTS "customers_update_own_user" ON public.users;
CREATE POLICY "customers_update_own_user" ON public.users FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "customers_update_own_profile" ON public.customer_profiles;
CREATE POLICY "customers_update_own_profile" ON public.customer_profiles FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 9) REALTIME: services, driver_locations, notifications, ratings (spec 51)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  _table_name text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH _table_name IN ARRAY ARRAY['services','driver_locations','notifications','ratings']
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = _table_name
      ) THEN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I;', _table_name);
      END IF;
    END LOOP;
  END IF;
END $$;

ALTER TABLE public.driver_locations REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;
ALTER TABLE public.ratings REPLICA IDENTITY FULL;

-- ---------------------------------------------------------------------------
-- 10) GAPS REALES DETECTADOS CONTRA LA BD EN VIVO (2026-09-05)
--   * vehicles NO tenía type/capacity_kg/photos (apps las usan)
--   * payments NO tenía paid_at (la app lo manda; el modelo lo lee)
--   * driver_profiles is_verified=FALSE en demo => cuenta "pendiente de
--     aprobación" -> forzamos verificado en modo demo
-- ---------------------------------------------------------------------------
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS type VARCHAR(20) NOT NULL DEFAULT 'camioneta';
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS capacity_kg INTEGER NOT NULL DEFAULT 500;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS photos TEXT[] NOT NULL DEFAULT '{}';

ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

UPDATE public.driver_profiles SET is_verified = TRUE WHERE is_verified IS DISTINCT FROM TRUE;

-- ---------------------------------------------------------------------------
-- 11) GAPS REALES DETECTADOS EN PRUEBA E2E (2026-09-05)
--   * notifications NO tenía columna data (notify_user la inserta)
--   * notification_type_enum no tenía los valores que usan los triggers/RPCs
-- ---------------------------------------------------------------------------
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS data JSONB DEFAULT '{}';

ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'service_accepted';
ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'service_arrival';
ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'service_started';
ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'service_completed';
ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'service_cancelled';
ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'service_cancelled_by_driver';
ALTER TYPE public.notification_type_enum ADD VALUE IF NOT EXISTS 'new_rating';

-- ---------------------------------------------------------------------------
-- 12) GAPS 3 (2026-09-05): driver_locations necesita UNIQUE en driver_id
--     (el upsert onConflict:'driver_id' de las apps lo exige)
-- ---------------------------------------------------------------------------
DELETE FROM public.driver_locations a
  USING public.driver_locations b
  WHERE a.driver_id = b.driver_id AND a.updated_at < b.updated_at;

CREATE UNIQUE INDEX IF NOT EXISTS driver_locations_driver_id_key
  ON public.driver_locations(driver_id);

-- ---------------------------------------------------------------------------
-- 13) GAPS 4 (2026-09-05): registro de clientes rompe por RLS.
--     * La app cliente inserta en users+customer_profiles al registrarse.
--     * schema.sql tenia "update/view" pero NUNCA hicimos INSERT en users,
--       asi que el registro del cliente falla y queda logueado SIN su fila
--       en users => createServiceProvider ve user==null y dice
--       "error al crear servicio" incluso con todos los campos llenos.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "customers_insert_own_user" ON public.users;
CREATE POLICY "customers_insert_own_user" ON public.users FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "customers_select_own_user" ON public.users;
CREATE POLICY "customers_select_own_user" ON public.users FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "customers_insert_own_profile" ON public.customer_profiles;
CREATE POLICY "customers_insert_own_profile" ON public.customer_profiles FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "customers_select_own_profile" ON public.customer_profiles;
CREATE POLICY "customers_select_own_profile" ON public.customer_profiles FOR SELECT TO authenticated
  USING (user_id = auth.uid());
-- ---------------------------------------------------------------------------
-- 14) LIMPIEZA de servicios de prueba creados durante las verificaciones REST
--     (aparecían como "servicios inventados" en la cola del conductor).
--     Solo borra las filas de automatización, NO las del flujo real.
--     Idempotente: los que ya no existen se ignoran.
-- ---------------------------------------------------------------------------
DELETE FROM public.services
WHERE id IN (
  '3b48bacb-01ef-490d-9ed8-b67e076729df', -- 'test' (REST)
  '29ba4030-9e02-4654-8aac-af418c9fe16b', -- 'test' (REST)
  'dada13f1-4831-43e0-82ac-ce2a350a12a4', -- 'tipo test muebles'
  '5d481258-f5b8-4963-86c3-303510a50271', -- 'tipo test electrodomesticos'
  '29b0b19b-43df-45ae-b260-72cf8e97feb4', -- 'tipo test cajas'
  'ba0ae463-7066-48f4-980d-2914963abe20', -- 'tipo test carga'
  'b24062b1-20bd-4359-abe3-c4148be2310b', -- 'tipo test otro'
  '6dab60eb-dc0f-401f-8485-6fe0716b7931', -- 'tipo test otros'
  '5198027a-4d43-4ac7-b91f-6e8f3e19ab5e' -- 'test' (REST)
) OR (
  status = 'solicitado'
  AND description LIKE 'tipo test%'
  AND created_at >= '2026-09-06T00:23:00Z'
  AND created_at <= '2026-09-06T00:24:00Z'
);
