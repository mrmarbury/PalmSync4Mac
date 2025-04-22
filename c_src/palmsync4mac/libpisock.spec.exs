module Libpisock

  interface [NIF]

  spec pi_connect(port:: string):: {:ok :: label, answer :: int}
