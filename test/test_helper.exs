ExUnit.start()

Mox.defmock(PalmSync4Mac.MockSystemCmd, for: PalmSync4Mac.Behaviour.SystemCmd)
Application.put_env(:palmsync4mac, :system_cmd, PalmSync4Mac.MockSystemCmd)
