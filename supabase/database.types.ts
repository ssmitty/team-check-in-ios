/**
 * database.types.ts
 * Purpose: Generated local database contract. Regenerate after schema changes.
 */
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          operationName?: string
          query?: string
          variables?: Json
          extensions?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      assignment_members: {
        Row: {
          assignment_id: string
          game_id: string
          user_id: string
        }
        Insert: {
          assignment_id: string
          game_id: string
          user_id: string
        }
        Update: {
          assignment_id?: string
          game_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "assignment_members_assignment_id_game_id_fkey"
            columns: ["assignment_id", "game_id"]
            isOneToOne: false
            referencedRelation: "assignments"
            referencedColumns: ["id", "game_id"]
          },
        ]
      }
      assignments: {
        Row: {
          created_at: string
          game_id: string
          id: string
        }
        Insert: {
          created_at?: string
          game_id: string
          id?: string
        }
        Update: {
          created_at?: string
          game_id?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "assignments_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
        ]
      }
      check_ins: {
        Row: {
          assignment_id: string
          feeling: string
          note: string
          support: string
          updated_at: string
          user_id: string
        }
        Insert: {
          assignment_id: string
          feeling: string
          note?: string
          support: string
          updated_at?: string
          user_id: string
        }
        Update: {
          assignment_id?: string
          feeling?: string
          note?: string
          support?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "check_ins_assignment_id_user_id_fkey"
            columns: ["assignment_id", "user_id"]
            isOneToOne: true
            referencedRelation: "assignment_members"
            referencedColumns: ["assignment_id", "user_id"]
          },
        ]
      }
      encouragements: {
        Row: {
          assignment_id: string
          message: string
          recipient_id: string
          sender_id: string
          updated_at: string
        }
        Insert: {
          assignment_id: string
          message: string
          recipient_id: string
          sender_id: string
          updated_at?: string
        }
        Update: {
          assignment_id?: string
          message?: string
          recipient_id?: string
          sender_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "encouragements_assignment_id_recipient_id_fkey"
            columns: ["assignment_id", "recipient_id"]
            isOneToOne: false
            referencedRelation: "assignment_members"
            referencedColumns: ["assignment_id", "user_id"]
          },
          {
            foreignKeyName: "encouragements_assignment_id_sender_id_fkey"
            columns: ["assignment_id", "sender_id"]
            isOneToOne: false
            referencedRelation: "assignment_members"
            referencedColumns: ["assignment_id", "user_id"]
          },
        ]
      }
      game_opt_outs: {
        Row: {
          game_id: string
          user_id: string
        }
        Insert: {
          game_id: string
          user_id: string
        }
        Update: {
          game_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_opt_outs_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["id"]
          },
        ]
      }
      games: {
        Row: {
          assignments_generated_at: string | null
          created_at: string
          id: string
          is_canceled: boolean
          location: string
          starts_at: string
          team_id: string
          time_zone_identifier: string
          title: string
          updated_at: string
        }
        Insert: {
          assignments_generated_at?: string | null
          created_at?: string
          id?: string
          is_canceled?: boolean
          location?: string
          starts_at: string
          team_id: string
          time_zone_identifier: string
          title: string
          updated_at?: string
        }
        Update: {
          assignments_generated_at?: string | null
          created_at?: string
          id?: string
          is_canceled?: boolean
          location?: string
          starts_at?: string
          team_id?: string
          time_zone_identifier?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "games_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      team_invites: {
        Row: {
          created_at: string
          expires_at: string
          id: string
          revoked_at: string | null
          team_id: string
          token: string
        }
        Insert: {
          created_at?: string
          expires_at?: string
          id?: string
          revoked_at?: string | null
          team_id: string
          token?: string
        }
        Update: {
          created_at?: string
          expires_at?: string
          id?: string
          revoked_at?: string | null
          team_id?: string
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_invites_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      team_members: {
        Row: {
          created_at: string
          display_name: string
          role: string
          team_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          display_name: string
          role?: string
          team_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          display_name?: string
          role?: string
          team_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_members_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      teams: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      commit_pairings: {
        Args: {
          p_game: string
          p_user: string
          p_context: Json
          p_groups: Json
        }
        Returns: boolean
      }
      create_invite: {
        Args: {
          p_team: string
        }
        Returns: string
      }
      create_team: {
        Args: {
          p_name: string
          p_display_name: string
        }
        Returns: string
      }
      pairing_context: {
        Args: {
          p_game: string
          p_user: string
        }
        Returns: Json
      }
      redeem_invite: {
        Args: {
          p_token: string
          p_display_name: string
        }
        Returns: string
      }
      revoke_invite: {
        Args: {
          p_token: string
        }
        Returns: undefined
      }
      save_game: {
        Args: {
          p_id: string
          p_team: string
          p_title: string
          p_starts_at: string
          p_location: string
          p_time_zone_identifier: string
          p_is_canceled?: boolean
        }
        Returns: string
      }
      send_encouragement: {
        Args: {
          p_assignment: string
          p_recipient: string
          p_message: string
        }
        Returns: undefined
      }
      set_game_opt_out: {
        Args: {
          p_game: string
          p_opt_out: boolean
        }
        Returns: undefined
      }
      submit_check_in: {
        Args: {
          p_assignment: string
          p_feeling: string
          p_support: string
          p_note: string
        }
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

type PublicSchema = Database[Extract<keyof Database, "public">]

export type Tables<
  PublicTableNameOrOptions extends
    | keyof (PublicSchema["Tables"] & PublicSchema["Views"])
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
        Database[PublicTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
      Database[PublicTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : PublicTableNameOrOptions extends keyof (PublicSchema["Tables"] &
        PublicSchema["Views"])
    ? (PublicSchema["Tables"] &
        PublicSchema["Views"])[PublicTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
    ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
    ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  PublicEnumNameOrOptions extends
    | keyof PublicSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends PublicEnumNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = PublicEnumNameOrOptions extends { schema: keyof Database }
  ? Database[PublicEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : PublicEnumNameOrOptions extends keyof PublicSchema["Enums"]
    ? PublicSchema["Enums"][PublicEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof PublicSchema["CompositeTypes"]
    | { schema: keyof Database },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof Database
  }
    ? keyof Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof Database }
  ? Database[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof PublicSchema["CompositeTypes"]
    ? PublicSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never
