-- Automatic history of EMS sensor readings.
-- Logs every insert and every update that changes a measurement column.

CREATE TABLE IF NOT EXISTS public.ems_sensordata_history (
  history_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id uuid NOT NULL,
  device_id uuid NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  iaq double precision,
  accuracy double precision,
  raw_temperature double precision,
  raw_pressure double precision,
  raw_humidity double precision,
  raw_gas double precision,
  stabilization_status double precision,
  run_in_status double precision,
  sensor_heat_compensated_temperature double precision,
  sensor_heat_compensated_humidity double precision,
  static_iaq double precision,
  co2_equivalent double precision,
  breath_voc_equivalent double precision,
  gas_percentage double precision,
  compensated_gas double precision,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  logged_at timestamp without time zone NOT NULL DEFAULT now(),
  operation text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE'))
);

CREATE INDEX IF NOT EXISTS idx_ems_sensordata_history_device_logged_at
  ON public.ems_sensordata_history (device_id, logged_at DESC);

CREATE INDEX IF NOT EXISTS idx_ems_sensordata_history_id
  ON public.ems_sensordata_history (id);

CREATE INDEX IF NOT EXISTS idx_ems_sensordata_history_user_id
  ON public.ems_sensordata_history (user_id);

ALTER TABLE public.ems_sensordata_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their device sensor history"
  ON public.ems_sensordata_history;

CREATE POLICY "Users can manage their device sensor history"
  ON public.ems_sensordata_history
  FOR ALL
  USING (
    device_id IN (
      SELECT d.id
      FROM devices d
      LEFT JOIN device_types dt ON d.device_type_id = dt.id
      LEFT JOIN rooms r ON dt.room_id = r.id
      LEFT JOIN floors f ON r.floor_id = f.id
      LEFT JOIN homes h ON f.home_id = h.id
      WHERE h.user_id = (SELECT auth.uid())
         OR d.user_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    device_id IN (
      SELECT d.id
      FROM devices d
      LEFT JOIN device_types dt ON d.device_type_id = dt.id
      LEFT JOIN rooms r ON dt.room_id = r.id
      LEFT JOIN floors f ON r.floor_id = f.id
      LEFT JOIN homes h ON f.home_id = h.id
      WHERE h.user_id = (SELECT auth.uid())
         OR d.user_id = (SELECT auth.uid())
    )
  );

GRANT SELECT ON public.ems_sensordata_history TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ems_sensordata_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ems_sensordata_history TO service_role;

CREATE OR REPLACE FUNCTION public.log_ems_sensor_history()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (
       OLD.iaq IS DISTINCT FROM NEW.iaq
    OR OLD.accuracy IS DISTINCT FROM NEW.accuracy
    OR OLD.raw_temperature IS DISTINCT FROM NEW.raw_temperature
    OR OLD.raw_pressure IS DISTINCT FROM NEW.raw_pressure
    OR OLD.raw_humidity IS DISTINCT FROM NEW.raw_humidity
    OR OLD.raw_gas IS DISTINCT FROM NEW.raw_gas
    OR OLD.stabilization_status IS DISTINCT FROM NEW.stabilization_status
    OR OLD.run_in_status IS DISTINCT FROM NEW.run_in_status
    OR OLD.sensor_heat_compensated_temperature IS DISTINCT FROM NEW.sensor_heat_compensated_temperature
    OR OLD.sensor_heat_compensated_humidity IS DISTINCT FROM NEW.sensor_heat_compensated_humidity
    OR OLD.static_iaq IS DISTINCT FROM NEW.static_iaq
    OR OLD.co2_equivalent IS DISTINCT FROM NEW.co2_equivalent
    OR OLD.breath_voc_equivalent IS DISTINCT FROM NEW.breath_voc_equivalent
    OR OLD.gas_percentage IS DISTINCT FROM NEW.gas_percentage
    OR OLD.compensated_gas IS DISTINCT FROM NEW.compensated_gas
  ) THEN
    INSERT INTO public.ems_sensordata_history (
      id,
      device_id,
      user_id,
      iaq,
      accuracy,
      raw_temperature,
      raw_pressure,
      raw_humidity,
      raw_gas,
      stabilization_status,
      run_in_status,
      sensor_heat_compensated_temperature,
      sensor_heat_compensated_humidity,
      static_iaq,
      co2_equivalent,
      breath_voc_equivalent,
      gas_percentage,
      compensated_gas,
      created_at,
      updated_at,
      operation
    ) VALUES (
      NEW.id,
      NEW.device_id,
      NEW.user_id,
      NEW.iaq,
      NEW.accuracy,
      NEW.raw_temperature,
      NEW.raw_pressure,
      NEW.raw_humidity,
      NEW.raw_gas,
      NEW.stabilization_status,
      NEW.run_in_status,
      NEW.sensor_heat_compensated_temperature,
      NEW.sensor_heat_compensated_humidity,
      NEW.static_iaq,
      NEW.co2_equivalent,
      NEW.breath_voc_equivalent,
      NEW.gas_percentage,
      NEW.compensated_gas,
      NEW.created_at,
      NEW.updated_at,
      TG_OP
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_ems_sensor_history ON public.ems_sensordata;

CREATE TRIGGER trigger_ems_sensor_history
  AFTER INSERT OR UPDATE ON public.ems_sensordata
  FOR EACH ROW
  EXECUTE FUNCTION public.log_ems_sensor_history();
