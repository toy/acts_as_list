module ActsAsList
  module ClassMethods
    # nothing here, folks
  end

  module InstanceMethods
    # Return the next higher item in the list.
    def higher_item
      return nil unless in_list?
      acts_as_list_class.where(
        "#{scope_condition} AND #{position_column} < #{send(position_column).to_s}"
      ).order("#{position_column} DESC").first
    end

    # Return the next lower item in the list.
    def lower_item
      return nil unless in_list?
      acts_as_list_class.where(
        "#{scope_condition} AND #{position_column} > #{send(position_column).to_s}"
      ).order("#{position_column} ASC").first
    end
  
    private
      # Returns the bottom item
      def bottom_item(except = nil)
        conditions = scope_condition
        conditions = "#{conditions} AND #{self.class.primary_key} != #{except.id}" if except
        acts_as_list_class.where(conditions).order("#{position_column} DESC").first
      end
    
      # This has the effect of moving all the higher items up one.
      def decrement_positions_on_higher_items(position)
        acts_as_list_class.where("#{scope_condition} AND #{position_column} <= #{position}").update_all("#{position_column} = (#{position_column} - 1)")
      end

      # This has the effect of moving all the lower items up one.
      def decrement_positions_on_lower_items
        return unless in_list?
        acts_as_list_class.where("#{scope_condition} AND #{position_column} > #{send(position_column).to_i}").update_all("#{position_column} = (#{position_column} - 1)")
      end

      # This has the effect of moving all the higher items down one.
      def increment_positions_on_higher_items
        return unless in_list?
        acts_as_list_class.where("#{scope_condition} AND #{position_column} < #{send(position_column).to_i}").update_all("#{position_column} = (#{position_column} + 1)")
      end

      # This has the effect of moving all the lower items down one.
      def increment_positions_on_lower_items(position)
        acts_as_list_class.where("#{scope_condition} AND #{position_column} >= #{position}").update_all("#{position_column} = (#{position_column} + 1)")
      end

      # Increments position (<tt>position_column</tt>) of all items in the list.
      def increment_positions_on_all_items
        acts_as_list_class.where("#{scope_condition}").update_all("#{position_column} = (#{position_column} + 1)")
      end
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end
