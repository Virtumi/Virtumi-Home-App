export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.4"
  }
  public: {
    Tables: {
      app_settings: {
        Row: {
          biometric_enabled: boolean
          connection_mode: string
          created_at: string
          dark_mode: boolean
          language: string
          pin_enabled: boolean
          two_factor_enabled: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          biometric_enabled?: boolean
          connection_mode?: string
          created_at?: string
          dark_mode?: boolean
          language?: string
          pin_enabled?: boolean
          two_factor_enabled?: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          biometric_enabled?: boolean
          connection_mode?: string
          created_at?: string
          dark_mode?: boolean
          language?: string
          pin_enabled?: boolean
          two_factor_enabled?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      cp_btn_requests: {
        Row: {
          command: number
          completed_at: string | null
          created_at: string | null
          device_id: string
          error_message: string | null
          id: string
          status: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          command: number
          completed_at?: string | null
          created_at?: string | null
          device_id: string
          error_message?: string | null
          id?: string
          status?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          command?: number
          completed_at?: string | null
          created_at?: string | null
          device_id?: string
          error_message?: string | null
          id?: string
          status?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "cp_btn_requests_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      cp_general_settings: {
        Row: {
          brightness: number | null
          cmd_date: string | null
          cmd_end: string | null
          cmd_start: string | null
          created_at: string | null
          device_id: string
          id: string
          led_state: number
          logger_active: boolean | null
          mode: number | null
          rgb_color_b: number | null
          rgb_color_g: number | null
          rgb_color_r: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          brightness?: number | null
          cmd_date?: string | null
          cmd_end?: string | null
          cmd_start?: string | null
          created_at?: string | null
          device_id: string
          id?: string
          led_state?: number
          logger_active?: boolean | null
          mode?: number | null
          rgb_color_b?: number | null
          rgb_color_g?: number | null
          rgb_color_r?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          brightness?: number | null
          cmd_date?: string | null
          cmd_end?: string | null
          cmd_start?: string | null
          created_at?: string | null
          device_id?: string
          id?: string
          led_state?: number
          logger_active?: boolean | null
          mode?: number | null
          rgb_color_b?: number | null
          rgb_color_g?: number | null
          rgb_color_r?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      cp_parameters: {
        Row: {
          active: number
          channel: number
          code: string
          command_0_active: number
          command_0_exists: number
          command_0_function: number
          command_0_protokol_nr: number
          command_1_active: number
          command_1_exists: number
          command_1_function: number
          command_1_protokol_nr: number
          command_2_active: number
          command_2_exists: number
          command_2_function: number
          command_2_protokol_nr: number
          created_at: string | null
          device_id: string
          device_type: number
          enabled: number
          id: string
          init: number
          ip_address: string
          ipv6: string
          mac_address: string
          mode: number
          name: string
          parameter_index: number
          port: number | null
          resource_name: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          active?: number
          channel?: number
          code?: string
          command_0_active?: number
          command_0_exists?: number
          command_0_function?: number
          command_0_protokol_nr?: number
          command_1_active?: number
          command_1_exists?: number
          command_1_function?: number
          command_1_protokol_nr?: number
          command_2_active?: number
          command_2_exists?: number
          command_2_function?: number
          command_2_protokol_nr?: number
          created_at?: string | null
          device_id: string
          device_type?: number
          enabled?: number
          id?: string
          init?: number
          ip_address?: string
          ipv6?: string
          mac_address?: string
          mode?: number
          name?: string
          parameter_index: number
          port?: number | null
          resource_name?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          active?: number
          channel?: number
          code?: string
          command_0_active?: number
          command_0_exists?: number
          command_0_function?: number
          command_0_protokol_nr?: number
          command_1_active?: number
          command_1_exists?: number
          command_1_function?: number
          command_1_protokol_nr?: number
          command_2_active?: number
          command_2_exists?: number
          command_2_function?: number
          command_2_protokol_nr?: number
          created_at?: string | null
          device_id?: string
          device_type?: number
          enabled?: number
          id?: string
          init?: number
          ip_address?: string
          ipv6?: string
          mac_address?: string
          mode?: number
          name?: string
          parameter_index?: number
          port?: number | null
          resource_name?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cp_parameters_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_data: {
        Row: {
          data: Json
          device_id: string | null
          id: string
          received_at: string
        }
        Insert: {
          data: Json
          device_id?: string | null
          id?: string
          received_at?: string
        }
        Update: {
          data?: Json
          device_id?: string | null
          id?: string
          received_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_data_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_datetime_settings: {
        Row: {
          city: string | null
          country: string | null
          created_at: string | null
          date: string
          device_id: string
          id: string
          latitude: number | null
          longitude: number | null
          ntp_server: string
          ntp_server_2: string | null
          ntp_server_active: boolean
          time: string
          time_change_active: boolean
          timezone: string
          timezone_name: string | null
          timezonename: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          city?: string | null
          country?: string | null
          created_at?: string | null
          date?: string
          device_id: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          ntp_server?: string
          ntp_server_2?: string | null
          ntp_server_active?: boolean
          time?: string
          time_change_active?: boolean
          timezone?: string
          timezone_name?: string | null
          timezonename?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          city?: string | null
          country?: string | null
          created_at?: string | null
          date?: string
          device_id?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          ntp_server?: string
          ntp_server_2?: string | null
          ntp_server_active?: boolean
          time?: string
          time_change_active?: boolean
          timezone?: string
          timezone_name?: string | null
          timezonename?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "device_datetime_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_location_settings: {
        Row: {
          created_at: string | null
          device_id: string
          floor: string | null
          home: string | null
          id: string
          name: string | null
          room: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          device_id: string
          floor?: string | null
          home?: string | null
          id?: string
          name?: string | null
          room?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          device_id?: string
          floor?: string | null
          home?: string | null
          id?: string
          name?: string | null
          room?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      device_mqtt_settings: {
        Row: {
          created_at: string | null
          device_id: string
          id: string
          mqtt_active: boolean
          mqtt_allow_anonymous: boolean
          mqtt_clean_session: boolean
          mqtt_connected: boolean
          mqtt_connection_error: string | null
          mqtt_customer_number: string
          mqtt_last_connected_at: string | null
          mqtt_password: string
          mqtt_port: number
          mqtt_qos: number
          mqtt_retain: boolean
          mqtt_server: string
          mqtt_user: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          device_id: string
          id?: string
          mqtt_active?: boolean
          mqtt_allow_anonymous?: boolean
          mqtt_clean_session?: boolean
          mqtt_connected?: boolean
          mqtt_connection_error?: string | null
          mqtt_customer_number?: string
          mqtt_last_connected_at?: string | null
          mqtt_password?: string
          mqtt_port?: number
          mqtt_qos?: number
          mqtt_retain?: boolean
          mqtt_server?: string
          mqtt_user?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          device_id?: string
          id?: string
          mqtt_active?: boolean
          mqtt_allow_anonymous?: boolean
          mqtt_clean_session?: boolean
          mqtt_connected?: boolean
          mqtt_connection_error?: string | null
          mqtt_customer_number?: string
          mqtt_last_connected_at?: string | null
          mqtt_password?: string
          mqtt_port?: number
          mqtt_qos?: number
          mqtt_retain?: boolean
          mqtt_server?: string
          mqtt_user?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "device_mqtt_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_network_settings: {
        Row: {
          created_at: string | null
          device_id: string
          hostname: string
          id: string
          port: number
          updated_at: string | null
          user_id: string | null
          wifi_mode: number
        }
        Insert: {
          created_at?: string | null
          device_id: string
          hostname?: string
          id?: string
          port?: number
          updated_at?: string | null
          user_id?: string | null
          wifi_mode?: number
        }
        Update: {
          created_at?: string | null
          device_id?: string
          hostname?: string
          id?: string
          port?: number
          updated_at?: string | null
          user_id?: string | null
          wifi_mode?: number
        }
        Relationships: [
          {
            foreignKeyName: "fk_device_network_settings_device"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_secret: {
        Row: {
          change_status: number
          created_at: string
          device_code: string
          device_code_new: string
          device_id: string
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          change_status?: number
          created_at?: string
          device_code: string
          device_code_new: string
          device_id: string
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          change_status?: number
          created_at?: string
          device_code?: string
          device_code_new?: string
          device_id?: string
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_secret_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_settings: {
        Row: {
          device_id: string | null
          id: string
          setting_key: string
          setting_type: string
          setting_value: Json | null
          updated_at: string
        }
        Insert: {
          device_id?: string | null
          id?: string
          setting_key: string
          setting_type: string
          setting_value?: Json | null
          updated_at?: string
        }
        Update: {
          device_id?: string | null
          id?: string
          setting_key?: string
          setting_type?: string
          setting_value?: Json | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_softap_details: {
        Row: {
          created_at: string | null
          device_id: string
          dhcpsvrip: string
          dnsip: string
          gwip: string
          id: string
          ip: string
          mac: string
          netmask: string
          networ_type: number
          port: number
          updated_at: string | null
          user_id: string | null
          websvrip: string
        }
        Insert: {
          created_at?: string | null
          device_id: string
          dhcpsvrip?: string
          dnsip?: string
          gwip?: string
          id?: string
          ip?: string
          mac?: string
          netmask?: string
          networ_type?: number
          port?: number
          updated_at?: string | null
          user_id?: string | null
          websvrip?: string
        }
        Update: {
          created_at?: string | null
          device_id?: string
          dhcpsvrip?: string
          dnsip?: string
          gwip?: string
          id?: string
          ip?: string
          mac?: string
          netmask?: string
          networ_type?: number
          port?: number
          updated_at?: string | null
          user_id?: string | null
          websvrip?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_device_softap_details_device"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_softap_settings: {
        Row: {
          active_conn: number
          channel: number
          created_at: string | null
          device_id: string
          ecn: number
          id: string
          password: string | null
          ssid: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          active_conn?: number
          channel?: number
          created_at?: string | null
          device_id: string
          ecn?: number
          id?: string
          password?: string | null
          ssid?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          active_conn?: number
          channel?: number
          created_at?: string | null
          device_id?: string
          ecn?: number
          id?: string
          password?: string | null
          ssid?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_device_softap_settings_device"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_station_details: {
        Row: {
          created_at: string | null
          device_id: string
          dhcpsvrip: string
          dnsip: string
          gwip: string
          id: string
          ip: string
          mac: string
          netmask: string
          networ_type: number
          port: number
          updated_at: string | null
          user_id: string | null
          websvrip: string
        }
        Insert: {
          created_at?: string | null
          device_id: string
          dhcpsvrip?: string
          dnsip?: string
          gwip?: string
          id?: string
          ip?: string
          mac?: string
          netmask?: string
          networ_type?: number
          port?: number
          updated_at?: string | null
          user_id?: string | null
          websvrip?: string
        }
        Update: {
          created_at?: string | null
          device_id?: string
          dhcpsvrip?: string
          dnsip?: string
          gwip?: string
          id?: string
          ip?: string
          mac?: string
          netmask?: string
          networ_type?: number
          port?: number
          updated_at?: string | null
          user_id?: string | null
          websvrip?: string
        }
        Relationships: [
          {
            foreignKeyName: "fk_device_station_details_device"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_station_settings: {
        Row: {
          active_conn: number
          channel: number
          created_at: string | null
          device_id: string
          ecn: number
          id: string
          password: string | null
          ssid: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          active_conn?: number
          channel?: number
          created_at?: string | null
          device_id: string
          ecn?: number
          id?: string
          password?: string | null
          ssid?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          active_conn?: number
          channel?: number
          created_at?: string | null
          device_id?: string
          ecn?: number
          id?: string
          password?: string | null
          ssid?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_device_station_settings_device"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_types: {
        Row: {
          category: string | null
          created_at: string
          description: string | null
          icon: string | null
          id: string
          name: string
          room_id: string | null
          updated_at: string
        }
        Insert: {
          category?: string | null
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          name: string
          room_id?: string | null
          updated_at?: string
        }
        Update: {
          category?: string | null
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          name?: string
          room_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_types_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      device_update_status: {
        Row: {
          created_at: string | null
          device_id: string
          error_message: string | null
          last_update_request: string | null
          status: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          device_id: string
          error_message?: string | null
          last_update_request?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          device_id?: string
          error_message?: string | null
          last_update_request?: string | null
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "device_update_status_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      device_virtumi_cloud_settings: {
        Row: {
          active: number
          api_key: string
          connected: number | null
          created_at: string | null
          device_id: string
          id: string
          updated_at: string | null
          url: string
          user_email: string
          user_id: string
          user_password: string
        }
        Insert: {
          active?: number
          api_key?: string
          connected?: number | null
          created_at?: string | null
          device_id: string
          id?: string
          updated_at?: string | null
          url?: string
          user_email?: string
          user_id: string
          user_password?: string
        }
        Update: {
          active?: number
          api_key?: string
          connected?: number | null
          created_at?: string | null
          device_id?: string
          id?: string
          updated_at?: string | null
          url?: string
          user_email?: string
          user_id?: string
          user_password?: string
        }
        Relationships: [
          {
            foreignKeyName: "device_virtumi_cloud_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      devices: {
        Row: {
          created_at: string
          current_version: string | null
          description: string | null
          device_code: string | null
          device_type_id: string | null
          devicename: string | null
          espnow_mac: string | null
          hostname: string | null
          id: string
          ip_address: string | null
          last_seen: string | null
          mac_address: string | null
          name: string
          port: string | null
          serial_number: string | null
          settings: Json | null
          status: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          current_version?: string | null
          description?: string | null
          device_code?: string | null
          device_type_id?: string | null
          devicename?: string | null
          espnow_mac?: string | null
          hostname?: string | null
          id?: string
          ip_address?: string | null
          last_seen?: string | null
          mac_address?: string | null
          name: string
          port?: string | null
          serial_number?: string | null
          settings?: Json | null
          status?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          current_version?: string | null
          description?: string | null
          device_code?: string | null
          device_type_id?: string | null
          devicename?: string | null
          espnow_mac?: string | null
          hostname?: string | null
          id?: string
          ip_address?: string | null
          last_seen?: string | null
          mac_address?: string | null
          name?: string
          port?: string | null
          serial_number?: string | null
          settings?: Json | null
          status?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "devices_device_type_id_fkey"
            columns: ["device_type_id"]
            isOneToOne: false
            referencedRelation: "device_types"
            referencedColumns: ["id"]
          },
        ]
      }
      ems_general_settings: {
        Row: {
          brightness: number | null
          cmd_date: string | null
          cmd_end: string | null
          cmd_start: string | null
          created_at: string | null
          device_id: string
          id: string
          led_state: number
          logger_active: boolean | null
          mode: number | null
          rgb_color_b: number | null
          rgb_color_g: number | null
          rgb_color_r: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          brightness?: number | null
          cmd_date?: string | null
          cmd_end?: string | null
          cmd_start?: string | null
          created_at?: string | null
          device_id: string
          id?: string
          led_state?: number
          logger_active?: boolean | null
          mode?: number | null
          rgb_color_b?: number | null
          rgb_color_g?: number | null
          rgb_color_r?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          brightness?: number | null
          cmd_date?: string | null
          cmd_end?: string | null
          cmd_start?: string | null
          created_at?: string | null
          device_id?: string
          id?: string
          led_state?: number
          logger_active?: boolean | null
          mode?: number | null
          rgb_color_b?: number | null
          rgb_color_g?: number | null
          rgb_color_r?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      ems_sensordata: {
        Row: {
          accuracy: number | null
          breath_voc_equivalent: number | null
          co2_equivalent: number | null
          compensated_gas: number | null
          created_at: string | null
          device_id: string
          gas_percentage: number | null
          iaq: number | null
          id: string
          raw_gas: number | null
          raw_humidity: number | null
          raw_pressure: number | null
          raw_temperature: number | null
          run_in_status: number | null
          sensor_heat_compensated_humidity: number | null
          sensor_heat_compensated_temperature: number | null
          stabilization_status: number | null
          static_iaq: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          accuracy?: number | null
          breath_voc_equivalent?: number | null
          co2_equivalent?: number | null
          compensated_gas?: number | null
          created_at?: string | null
          device_id: string
          gas_percentage?: number | null
          iaq?: number | null
          id?: string
          raw_gas?: number | null
          raw_humidity?: number | null
          raw_pressure?: number | null
          raw_temperature?: number | null
          run_in_status?: number | null
          sensor_heat_compensated_humidity?: number | null
          sensor_heat_compensated_temperature?: number | null
          stabilization_status?: number | null
          static_iaq?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          accuracy?: number | null
          breath_voc_equivalent?: number | null
          co2_equivalent?: number | null
          compensated_gas?: number | null
          created_at?: string | null
          device_id?: string
          gas_percentage?: number | null
          iaq?: number | null
          id?: string
          raw_gas?: number | null
          raw_humidity?: number | null
          raw_pressure?: number | null
          raw_temperature?: number | null
          run_in_status?: number | null
          sensor_heat_compensated_humidity?: number | null
          sensor_heat_compensated_temperature?: number | null
          stabilization_status?: number | null
          static_iaq?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      ems_sensordata_history: {
        Row: {
          accuracy: number | null
          breath_voc_equivalent: number | null
          co2_equivalent: number | null
          compensated_gas: number | null
          created_at: string | null
          device_id: string
          gas_percentage: number | null
          history_id: string
          iaq: number | null
          id: string
          logged_at: string
          operation: string
          raw_gas: number | null
          raw_humidity: number | null
          raw_pressure: number | null
          raw_temperature: number | null
          run_in_status: number | null
          sensor_heat_compensated_humidity: number | null
          sensor_heat_compensated_temperature: number | null
          stabilization_status: number | null
          static_iaq: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          accuracy?: number | null
          breath_voc_equivalent?: number | null
          co2_equivalent?: number | null
          compensated_gas?: number | null
          created_at?: string | null
          device_id: string
          gas_percentage?: number | null
          history_id?: string
          iaq?: number | null
          id: string
          logged_at?: string
          operation: string
          raw_gas?: number | null
          raw_humidity?: number | null
          raw_pressure?: number | null
          raw_temperature?: number | null
          run_in_status?: number | null
          sensor_heat_compensated_humidity?: number | null
          sensor_heat_compensated_temperature?: number | null
          stabilization_status?: number | null
          static_iaq?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          accuracy?: number | null
          breath_voc_equivalent?: number | null
          co2_equivalent?: number | null
          compensated_gas?: number | null
          created_at?: string | null
          device_id?: string
          gas_percentage?: number | null
          history_id?: string
          iaq?: number | null
          id?: string
          logged_at?: string
          operation?: string
          raw_gas?: number | null
          raw_humidity?: number | null
          raw_pressure?: number | null
          raw_temperature?: number | null
          run_in_status?: number | null
          sensor_heat_compensated_humidity?: number | null
          sensor_heat_compensated_temperature?: number | null
          stabilization_status?: number | null
          static_iaq?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      floors: {
        Row: {
          created_at: string
          description: string | null
          floor_number: number | null
          home_id: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          floor_number?: number | null
          home_id?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          floor_number?: number | null
          home_id?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "floors_home_id_fkey"
            columns: ["home_id"]
            isOneToOne: false
            referencedRelation: "homes"
            referencedColumns: ["id"]
          },
        ]
      }
      homes: {
        Row: {
          address: string | null
          created_at: string
          description: string | null
          id: string
          name: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          address?: string | null
          created_at?: string
          description?: string | null
          id?: string
          name: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          address?: string | null
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      livecom: {
        Row: {
          authenticated: boolean | null
          counter: number
          created_at: string
          device_id: string
          free_heap: number | null
          id: number
          mac_address: string
          realtime_connected: boolean | null
          rssi: number | null
          supabase_connected: boolean | null
          timestamp: number
          updated_at: string
          uptime: number | null
          user_id: string | null
          wifi_connected: boolean | null
        }
        Insert: {
          authenticated?: boolean | null
          counter: number
          created_at?: string
          device_id: string
          free_heap?: number | null
          id?: number
          mac_address: string
          realtime_connected?: boolean | null
          rssi?: number | null
          supabase_connected?: boolean | null
          timestamp: number
          updated_at?: string
          uptime?: number | null
          user_id?: string | null
          wifi_connected?: boolean | null
        }
        Update: {
          authenticated?: boolean | null
          counter?: number
          created_at?: string
          device_id?: string
          free_heap?: number | null
          id?: number
          mac_address?: string
          realtime_connected?: boolean | null
          rssi?: number | null
          supabase_connected?: boolean | null
          timestamp?: number
          updated_at?: string
          uptime?: number | null
          user_id?: string | null
          wifi_connected?: boolean | null
        }
        Relationships: []
      }
      matter_requests: {
        Row: {
          command: number
          completed_at: string | null
          created_at: string | null
          device_id: string
          error_message: string | null
          id: string
          status: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          command?: number
          completed_at?: string | null
          created_at?: string | null
          device_id: string
          error_message?: string | null
          id?: string
          status?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          command?: number
          completed_at?: string | null
          created_at?: string | null
          device_id?: string
          error_message?: string | null
          id?: string
          status?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "matter_requests_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      matter_settings: {
        Row: {
          commissioning_flow: string
          created_at: string | null
          device_id: string
          discriminator: number
          id: string
          is_commissioned: boolean
          pairing_active: number
          product_id: number
          qr_code: string | null
          rendezvous_info: string
          setup_passcode: string
          updated_at: string | null
          user_id: string
          vendor_id: number
        }
        Insert: {
          commissioning_flow?: string
          created_at?: string | null
          device_id: string
          discriminator?: number
          id?: string
          is_commissioned?: boolean
          pairing_active?: number
          product_id?: number
          qr_code?: string | null
          rendezvous_info?: string
          setup_passcode?: string
          updated_at?: string | null
          user_id: string
          vendor_id?: number
        }
        Update: {
          commissioning_flow?: string
          created_at?: string | null
          device_id?: string
          discriminator?: number
          id?: string
          is_commissioned?: boolean
          pairing_active?: number
          product_id?: number
          qr_code?: string | null
          rendezvous_info?: string
          setup_passcode?: string
          updated_at?: string | null
          user_id?: string
          vendor_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "matter_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      otadata: {
        Row: {
          created_at: string
          device_type: string | null
          id: number
          update_file_url: string | null
          version: string | null
        }
        Insert: {
          created_at?: string
          device_type?: string | null
          id?: number
          update_file_url?: string | null
          version?: string | null
        }
        Update: {
          created_at?: string
          device_type?: string | null
          id?: number
          update_file_url?: string | null
          version?: string | null
        }
        Relationships: []
      }
      rooms: {
        Row: {
          created_at: string
          description: string | null
          floor_id: string | null
          id: string
          name: string
          room_type: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          floor_id?: string | null
          id?: string
          name: string
          room_type?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          floor_id?: string | null
          id?: string
          name?: string
          room_type?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rooms_floor_id_fkey"
            columns: ["floor_id"]
            isOneToOne: false
            referencedRelation: "floors"
            referencedColumns: ["id"]
          },
        ]
      }
      smart_led_general_settings: {
        Row: {
          brightness: number | null
          cmd_date: string | null
          cmd_end: string | null
          cmd_start: string | null
          created_at: string
          device_id: string
          id: string
          led_state: number | null
          logger_active: boolean | null
          rgb_color_b: number | null
          rgb_color_g: number | null
          rgb_color_r: number | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          brightness?: number | null
          cmd_date?: string | null
          cmd_end?: string | null
          cmd_start?: string | null
          created_at?: string
          device_id: string
          id?: string
          led_state?: number | null
          logger_active?: boolean | null
          rgb_color_b?: number | null
          rgb_color_g?: number | null
          rgb_color_r?: number | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          brightness?: number | null
          cmd_date?: string | null
          cmd_end?: string | null
          cmd_start?: string | null
          created_at?: string
          device_id?: string
          id?: string
          led_state?: number | null
          logger_active?: boolean | null
          rgb_color_b?: number | null
          rgb_color_g?: number | null
          rgb_color_r?: number | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "smart_led_general_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: true
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      smart_led_settings: {
        Row: {
          auto_mode: number | null
          auto_mode_time: number | null
          available: number
          brightness: number | null
          device_id: string
          effect_number: number | null
          led_count: number | null
          led_function_nr: number | null
          led_index: number
          led_on: number | null
          max_brightness: number | null
          off_automatic: number | null
          off_time: string | null
          rgb_color_b: number | null
          rgb_color_b2: number | null
          rgb_color_g: number | null
          rgb_color_g2: number | null
          rgb_color_r: number | null
          rgb_color_r2: number | null
          speed: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          auto_mode?: number | null
          auto_mode_time?: number | null
          available?: number
          brightness?: number | null
          device_id: string
          effect_number?: number | null
          led_count?: number | null
          led_function_nr?: number | null
          led_index: number
          led_on?: number | null
          max_brightness?: number | null
          off_automatic?: number | null
          off_time?: string | null
          rgb_color_b?: number | null
          rgb_color_b2?: number | null
          rgb_color_g?: number | null
          rgb_color_g2?: number | null
          rgb_color_r?: number | null
          rgb_color_r2?: number | null
          speed?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          auto_mode?: number | null
          auto_mode_time?: number | null
          available?: number
          brightness?: number | null
          device_id?: string
          effect_number?: number | null
          led_count?: number | null
          led_function_nr?: number | null
          led_index?: number
          led_on?: number | null
          max_brightness?: number | null
          off_automatic?: number | null
          off_time?: string | null
          rgb_color_b?: number | null
          rgb_color_b2?: number | null
          rgb_color_g?: number | null
          rgb_color_g2?: number | null
          rgb_color_r?: number | null
          rgb_color_r2?: number | null
          speed?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "smart_led_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      smart_led_triggers: {
        Row: {
          active: number
          brightness: number
          change_brightness: number
          change_led_effect: number
          change_off_automatic: number
          change_switch_state: number
          command_date_day: number
          command_date_month: number
          command_date_year: number
          command_time_hour: number
          command_time_minute: number
          command_time_second: number
          created_at: string | null
          device_id: string
          done: number
          effect_number: number
          id: string
          lamp_on: number
          name: string
          off_automatic: number
          off_automatic_time_hour: number
          off_automatic_time_minute: number
          off_automatic_time_second: number
          parameter_index: number
          trigger_type: number
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          active?: number
          brightness?: number
          change_brightness?: number
          change_led_effect?: number
          change_off_automatic?: number
          change_switch_state?: number
          command_date_day?: number
          command_date_month?: number
          command_date_year?: number
          command_time_hour?: number
          command_time_minute?: number
          command_time_second?: number
          created_at?: string | null
          device_id: string
          done?: number
          effect_number?: number
          id?: string
          lamp_on?: number
          name?: string
          off_automatic?: number
          off_automatic_time_hour?: number
          off_automatic_time_minute?: number
          off_automatic_time_second?: number
          parameter_index: number
          trigger_type?: number
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          active?: number
          brightness?: number
          change_brightness?: number
          change_led_effect?: number
          change_off_automatic?: number
          change_switch_state?: number
          command_date_day?: number
          command_date_month?: number
          command_date_year?: number
          command_time_hour?: number
          command_time_minute?: number
          command_time_second?: number
          created_at?: string | null
          device_id?: string
          done?: number
          effect_number?: number
          id?: string
          lamp_on?: number
          name?: string
          off_automatic?: number
          off_automatic_time_hour?: number
          off_automatic_time_minute?: number
          off_automatic_time_second?: number
          parameter_index?: number
          trigger_type?: number
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "smart_led_triggers_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      update_requests: {
        Row: {
          command: number
          completed_at: string | null
          created_at: string | null
          device_id: string
          error_message: string | null
          id: string
          status: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          command?: number
          completed_at?: string | null
          created_at?: string | null
          device_id: string
          error_message?: string | null
          id?: string
          status?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          command?: number
          completed_at?: string | null
          created_at?: string | null
          device_id?: string
          error_message?: string | null
          id?: string
          status?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "update_requests_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      update_settings: {
        Row: {
          active: number
          created_at: string | null
          current_version: string | null
          day: number | null
          device_id: string
          id: string
          mode: number
          time: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          active?: number
          created_at?: string | null
          current_version?: string | null
          day?: number | null
          device_id: string
          id?: string
          mode: number
          time: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          active?: number
          created_at?: string | null
          current_version?: string | null
          day?: number | null
          device_id?: string
          id?: string
          mode?: number
          time?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "update_settings_device_id_fkey"
            columns: ["device_id"]
            isOneToOne: false
            referencedRelation: "devices"
            referencedColumns: ["id"]
          },
        ]
      }
      user_profiles: {
        Row: {
          address_city: string
          address_country: string
          address_postal_code: string
          address_street: string
          avatar_url: string | null
          created_at: string
          first_name: string
          last_name: string
          phone: string
          updated_at: string
          user_id: string
        }
        Insert: {
          address_city?: string
          address_country?: string
          address_postal_code?: string
          address_street?: string
          avatar_url?: string | null
          created_at?: string
          first_name?: string
          last_name?: string
          phone?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          address_city?: string
          address_country?: string
          address_postal_code?: string
          address_street?: string
          avatar_url?: string | null
          created_at?: string
          first_name?: string
          last_name?: string
          phone?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      update_requests_stats: {
        Row: {
          completed_requests: number | null
          failed_requests: number | null
          newest_request: string | null
          oldest_request: string | null
          pending_requests: number | null
          table_size: string | null
          total_requests: number | null
          unique_devices: number | null
        }
        Relationships: []
      }
    }
    Functions: {
      cleanup_old_livecom_entries: { Args: never; Returns: undefined }
      cleanup_old_update_requests: { Args: never; Returns: undefined }
      get_active_cp_parameters: {
        Args: { target_device_id: string }
        Returns: {
          active: number
          channel: number
          code: string
          command_0_active: number
          command_0_exists: number
          command_0_function: number
          command_0_protokol_nr: number
          command_1_active: number
          command_1_exists: number
          command_1_function: number
          command_1_protokol_nr: number
          command_2_active: number
          command_2_exists: number
          command_2_function: number
          command_2_protokol_nr: number
          created_at: string | null
          device_id: string
          device_type: number
          enabled: number
          id: string
          init: number
          ip_address: string
          ipv6: string
          mac_address: string
          mode: number
          name: string
          parameter_index: number
          port: number | null
          resource_name: string
          updated_at: string | null
          user_id: string | null
        }[]
        SetofOptions: {
          from: "*"
          to: "cp_parameters"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      reset_cp_parameters: {
        Args: { target_device_id: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
