class Date
  def to_comscore_time_period
    initial_d = Date.new(2000, 1, 1)
    if self.to_time.to_i < initial_d.to_time.to_i
      raise "#{self.strftime("%Y-%m")} is before #{self.strftime("%Y-%m")}"
    end
    year_difference = self.year - initial_d.year
    month_difference = (self.month - initial_d.month).modulo(12)
    return (year_difference * 12) + month_difference + 1
  end
end