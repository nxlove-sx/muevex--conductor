-- ============================================================
-- MUEVEX CONDUCTOR - Migración de base de datos
-- Ejecutar en Supabase > SQL Editor (proyecto muevex).
-- Esta migración ES ADITIVA: no rompe la app cliente existente.
-- ============================================================

-- 0) Asegurar el enum driver_availability (puede no existir en la BD real)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'driver_availability') THEN
    CREATE TYPE driver_availability AS ENUM ('available', 'unavailable', 'busy');
  END IF;
END $$;

-- 1) driver_profiles: disponibilidad + presencia + foto
ALTER TABLE public.driver_profiles ADD COLUMN IF NOT EXISTS availability driver_availability NOT NULL DEFAULT 'unavailable';
ALTER TABLE public.driver_profiles ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
ALTER TABLE public.driver_profiles ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- 2) vehicles: datos adicionales para la app del conductor
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS year INTEGER DEFAULT 0;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS color VARCHAR(50);
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'pendiente';
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- 3) services: nombres legibles + timestamps del viaje
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS origin_name TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS destination_name TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
ALTER TABLE public.services ALTER COLUMN status SET DEFAULT 'requested';

-- 4) Ubicación en vivo del conductor (nueva tabla)
CREATE TABLE IF NOT EXISTS public.driver_locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
  latitude NUMERIC(10, 6) NOT NULL,
  longitude NUMERIC(10, 6) NOT NULL,
  heading REAL DEFAULT 0,
  speed REAL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_driver_locations_service
  ON public.driver_locations(service_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver
  ON public.driver_locations(driver_id, updated_at DESC);

-- 5) Aceptación atómica de un servicio (evita doble asignación)
CREATE OR REPLACE FUNCTION public.accept_service(p_service_id UUID)
RETURNS SETOF public.services
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  UPDATE public.services
     SET driver_id = auth.uid(),
         status = 'driver_accepted',
         accepted_at = NOW()
   WHERE id = p_service_id
     AND driver_id IS NULL
     AND status IN ('requested', 'searching_driver')
  RETURNING *;
$$;

-- 6) RLS: políticas para la app del conductor (aditivas)
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- driver_profiles: el conductor solo ve/edita su propio perfil
DROP POLICY IF EXISTS "drivers_select_own_profile" ON public.driver_profiles;
CREATE POLICY "drivers_select_own_profile" ON public.driver_profiles
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "drivers_update_own_profile" ON public.driver_profiles;
CREATE POLICY "drivers_update_own_profile" ON public.driver_profiles
  FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "drivers_insert_own_profile" ON public.driver_profiles;
CREATE POLICY "drivers_insert_own_profile" ON public.driver_profiles
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- services: el conductor ve solicitudes libres y sus propios servicios
DROP POLICY IF EXISTS "drivers_select_available_requests" ON public.services;
CREATE POLICY "drivers_select_available_requests" ON public.services
  FOR SELECT
  USING (
    (status IN ('requested', 'searching_driver') AND driver_id IS NULL)
    OR driver_id = auth.uid()
    OR customer_id = auth.uid()
  );

DROP POLICY IF EXISTS "drivers_update_own_services" ON public.services;
CREATE POLICY "drivers_update_own_services" ON public.services
  FOR UPDATE
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- vehicles: el conductor gestiona sus vehículos (por user id en driver_profiles.id)
DROP POLICY IF EXISTS "drivers_select_own_vehicles" ON public.vehicles;
CREATE POLICY "drivers_select_own_vehicles" ON public.vehicles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.driver_profiles dp
            WHERE dp.id = vehicles.driver_id AND dp.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "drivers_insert_own_vehicles" ON public.vehicles;
CREATE POLICY "drivers_insert_own_vehicles" ON public.vehicles
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.driver_profiles dp
            WHERE dp.id = vehicles.driver_id AND dp.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "drivers_update_own_vehicles" ON public.vehicles;
CREATE POLICY "drivers_update_own_vehicles" ON public.vehicles
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.driver_profiles dp
            WHERE dp.id = vehicles.driver_id AND dp.user_id = auth.uid())
  );

-- driver_locations: conductor escribe su ubicación, el cliente la lee
DROP POLICY IF EXISTS "drivers_insert_own_locations" ON public.driver_locations;
CREATE POLICY "drivers_insert_own_locations" ON public.driver_locations
  FOR INSERT WITH CHECK (driver_id = auth.uid());

DROP POLICY IF EXISTS "drivers_select_own_locations" ON public.driver_locations;
CREATE POLICY "drivers_select_own_locations" ON public.driver_locations
  FOR SELECT USING (driver_id = auth.uid());

DROP POLICY IF EXISTS "drivers_update_own_locations" ON public.driver_locations;
CREATE POLICY "drivers_update_own_locations" ON public.driver_locations
  FOR UPDATE USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

DROP POLICY IF EXISTS "customers_select_driver_locations" ON public.driver_locations;
CREATE POLICY "customers_select_driver_locations" ON public.driver_locations
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.services s
            WHERE s.id = service_id AND s.customer_id = auth.uid())
  );

-- notifications: cada usuario solo ve las suyas
DROP POLICY IF EXISTS "users_select_own_notifications" ON public.notifications;
CREATE POLICY "users_select_own_notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

-- ratings: el conductor ve las calificaciones que recibe
DROP POLICY IF EXISTS "users_select_own_ratings" ON public.ratings;
CREATE POLICY "users_select_own_ratings" ON public.ratings
  FOR SELECT USING (rated_id = auth.uid() OR rater_id = auth.uid());

-- users: la app del conductor inserta su perfil y lee el propio
DROP POLICY IF EXISTS "drivers_read_own_user" ON public.users;
CREATE POLICY "drivers_read_own_user" ON public.users
  FOR SELECT USING (id = auth.uid());

-- 7) Storage buckets para fotos del conductor y del vehículo
INSERT INTO storage.buckets (id, name, public)
SELECT 'driver-photos', 'driver-photos', TRUE
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'driver-photos');
INSERT INTO storage.buckets (id, name, public)
SELECT 'vehicle-photos', 'vehicle-photos', TRUE
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'vehicle-photos');

DROP POLICY IF EXISTS "conductor_upload_photos" ON storage.objects;
CREATE POLICY "conductor_upload_photos" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id IN ('driver-photos', 'vehicle-photos') AND owner = auth.uid());

DROP POLICY IF EXISTS "conductor_select_photos" ON storage.objects;
CREATE POLICY "conductor_select_photos" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id IN ('driver-photos', 'vehicle-photos'));

-- 8) Realtime: publicar cambios en services y driver_locations
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = 'services'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = 'driver_locations'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;
    END IF;
  END IF;
END $$;

ALTER TABLE public.services REPLICA IDENTITY FULL;
ALTER TABLE public.driver_locations REPLICA IDENTITY FULL;