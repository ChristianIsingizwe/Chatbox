defmodule IntroductionTest do
  use ExUnit.Case
  doctest Introduction

  test "greets the world" do
    assert Introduction.hello() == :world
  end
end
