module Tochka
  class Athsurvey
    FREQ2CHAN = {
      0     => 0, # why radiotap.channel.freq can be 0?
      # 2.4GHz
      2412  => 1,
      2417  => 2,
      2422  => 3,
      2427  => 4,
      2432  => 5,
      2437  => 6,
      2442  => 7,
      2447  => 8,
      2452  => 9,
      2457  => 10,
      2462  => 11,
      2467  => 12,
      2472  => 13,
      2484  => 14,

      # japan client only
      5170  => 34,
      5190  => 38,
      5210  => 42,
      5230  => 46,

      # W52
      5180  => 36,
      5200  => 40,
      5220  => 44,
      5240  => 48,

      # W53
      5260  => 52,
      5280  => 56,
      5300  => 60,
      5320  => 64,

      # W56
      5500  => 100,
      5520  => 104,
      5540  => 108,
      5560  => 112,
      5580  => 116,
      5600  => 120,
      5620  => 124,
      5640  => 128,
      5660  => 132,
      5680  => 136,
      5700  => 140,

      # 802.11j
      4920  => 184,
      4940  => 188,
      4960  => 192,
      4980  => 194,
    }

    REG_FREQ=/^frequency:\s+(\d+) /
    REG_ACTIVE=/^channel active time:\s+(\d+) (|m)s$/
    REG_BUSY=/^channel busy time:\s+(\d+) (|m)s$/

    def initialize ifname
      @ifname = ifname
    end

    def current_data
      str = get_survey_dump()
      active = 0
      busy = 0
      channel = 0

      str.split("\n").map{|line| line.strip}.each do |line|
        case line
        when REG_FREQ
          channel = FREQ2CHAN[$1.to_i]
        when REG_ACTIVE
          active = $1.to_i
          active *= 1000 if $2 != "m"
        when REG_BUSY
          busy = $1.to_i
          busy *= 1000 if $2 != "m"
        end
      end
      return [0, 0, 0] if active == 0

      return [channel, active, busy, fto2f(busy.to_f * 100 / active.to_f) ]
    end

    def get_survey_dump
      return `iw #{@ifname} survey dump`
    end

    def fto2f f
      return (f * 100).to_i.to_f / 100
    end
  end
end

if __FILE__ == $0
aths = Tochka::Athsurvey.new("wlan0")
p aths.current_data
end
