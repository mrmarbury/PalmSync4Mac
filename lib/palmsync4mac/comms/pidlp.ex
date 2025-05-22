defmodule PalmSync4Mac.Comms.Pidlp do
  @moduledoc """
  Implemntation of the PiDlp functions for Palm devices.
  """
  use Unifex.Loader
  use EnumType

  defenum RepeatType, :integer do
    value(None, 0)
    value(Daily, 1)
    value(Weekly, 2)
    value(MonthlyByDay, 3)
    value(MonthlyByDate, 4)
    value(Yearly, 5)
  end

  defenum AlarmAdvanceUnit, :integer do
    value(Minutes, 0)
    value(Hours, 1)
    value(Days, 2)
  end

  defenum DayOfMonthType, :integer do
    value(FirstSun, 1)
    value(FirstMon, 2)
    value(FirstTue, 3)
    value(FirstWen, 4)
    value(FirstThu, 5)
    value(FirstFri, 6)
    value(FirstSat, 7)
    value(SecondSun, 8)
    value(SecondMon, 9)
    value(SecondTue, 10)
    value(SecondWen, 11)
    value(SecondThu, 12)
    value(SecondFri, 13)
    value(SecondSat, 14)
    value(ThirdSun, 15)
    value(ThirdMon, 16)
    value(ThirdTue, 17)
    value(ThirdWen, 18)
    value(ThirdThu, 19)
    value(ThirdFri, 20)
    value(ThirdSat, 21)
    value(FourthSun, 22)
    value(FourthMon, 23)
    value(FourthTue, 24)
    value(FourthWen, 25)
    value(FourthThu, 26)
    value(FourthFri, 27)
    value(FourthSat, 28)
    value(LastSun, 29)
    value(LastMon, 30)
    value(LastTue, 31)
    value(LastWen, 32)
    value(LastThu, 33)
    value(LastFri, 34)
    value(LastSat, 35)
  end
end
