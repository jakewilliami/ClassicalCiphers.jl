import Base.uppercase

function uppercase(a::NTuple{N, Char}) where N
	uppercase.(a)
end

function parse_stecker(stecker::AbstractString)
	if !iseven(length(stecker))
		error("Stecker setting must be of even length.")
	end

	if isempty(stecker)
		steck_parsed = Tuple{Char, Char}[]
	else
		sp = collect(stecker)
		steck_parsed = Tuple{Char, Char}[(sp[i][1], sp[i + 1][1]) for i in 1:2:length(sp)]
	end
	return steck_parsed
end

function parse_stecker(stecker::Array{Tuple{Char, Char}})
	if isempty(stecker)
		return Array{Tuple{Char, Char}, 1}()
	else
		return stecker
	end
	return nothing
end

function parse_reflector(reflector::Char)
	if uppercase(reflector) == 'A'
		return "EJMZALYXVBWFCRQUONTSPIKHGD"
	elseif uppercase(reflector) == 'B'
		return "YRUHQSLDPXNGOKMIEBFZCWVJAT"
	elseif uppercase(reflector) == 'C'
		return "FVPJIAOYEDRZXWGCTKUQSBNMHL"
	else
		error("Reflector $(reflector) unrecognised.")
	end
	return nothing
end

function parse_reflector(reflector::AbstractString)
	if length(reflector) != 26
		error("Reflector must be a 26-char string.")
	end

	ans = uppercase(reflector)

	if ans != join(unique(ans))
		error("Reflector must not contain any character used more than once.")
	end

	return ans
end

"""
```julia
function encrypt_enigma(plaintext,
						rotors::Array{Integer, 1}, key::AbstractString;
						reflector_id='B', ring::AbstractString = "AAA",
						stecker = Tuple{Char, Char}[],
						skip_stecker_check = false)
```

Encrypts the given plaintext according to the Enigma (M3, army version).

Arguments are in the order: `plaintext, stecker, rotors, ring, key.`

Plaintext is a string; punctuation is stripped out and it is made lowercase.
Rotors is an array - for example, `[1,2,3]` - being the order of the rotors.
  Each entry should be a distinct integer between 1 and 5 inclusive.
Key is a string of three letters, indicating the starting positions of the rotors.

Optional:
 * `reflector_id='B'`, which sets whether to use reflector A, B or C.
  Can also be specified as a 26-char string.
 * Stecker is either an array - for example,` [('A','B'), ('D', 'E')]` specifying
  that A, B are swapped and D, E are swapped - or a string ("ABDE" accomplishing
  the same thing). No letter may appear more than once.
 * Ring is a string - for example, "AAA" - being the offset applied to each rotor.
  "AAA", for example, signifies no offset. The string must be three letters.
 * `skip_stecker_check=false`, which when `true` skips validation of stecker settings.
 
---

### Examples

```julia
julia> encrypt_enigma("AAA", [1,2,3], "ABC")
"CXT"

julia> encrypt_enigma("AAA", [1,2,3], "ABC", ring="AAA", reflector_id='B', stecker="") # synonymous with above
"CXT"

julia> encrypt_enigma("AAA", [1,2,3], "ABC", ring="AAA", reflector_id="YRUHQSLDPXNGOKMIEBFZCWVJAT", stecker="") # synonymous with above
"CXT"

julia> encrypt_enigma("AAA", [1,2,3], "ABC", ring="AAA", reflector_id='B', stecker=Tuple{Char, Char}[]) # synonymous with above
"CXT"
```
"""
function encrypt_enigma(plaintext,
						rotors::Array{T, 1}, key::AbstractString;
						reflector_id='B', ring::AbstractString = "AAA",
						stecker = Tuple{Char, Char}[],
						skip_stecker_check = false) where T <: Integer

	parsed_stecker = parse_stecker(stecker)
	# validate stecker settings
	if !skip_stecker_check
		# if collect(Iterators.flatten(parsed_stecker)) != collect(unique(Iterators.flatten(parsed_stecker)))
		if collect(parsed_stecker) != unique(parsed_stecker) # do we need to flatten? ^
			error("No letter may appear more than once in stecker settings.")
		end
	end
	parsed_stecker::Array{Tuple{Char, Char}} = map(uppercase, parsed_stecker)

	# validate ring settings
	if length(ring) != 3
		error("Ring settings must be a string of length 3.")
	end
	ring = uppercase(ring)
	for ch in ring
		if !('A' <= ch <= 'Z')
			error("Ring settings must be a string of Roman letters.")
		end
	end

	# validate key settings
	if length(key) != 3
		error("Key settings must be a string of length 3.")
	end
	key = uppercase(key)
	for ch in key
		if !('A' <= ch <= 'Z')
			error("Key settings must be a string of Roman letters.")
		end
	end

	# validate rotor settings
	for i in rotors
		if !(1 <= i <= 5)
			error("Each rotor must be an integer between 1 and 5.")
		end
	end
	if rotors != unique(rotors)
		error("No rotor may appear more than once.")
	end

	# validate reflector settings
	reflector = _keystr_to_dict(parse_reflector(reflector_id))

	# sanitise plaintext
	plaintext = uppercase(letters_only(plaintext))

	# initialisation of the machine
	rotor_layouts = ["EKMFLGDQVZNTOWYHXUSPAIBRCJ",
					 "AJDKSIRUXBLHWTMCQGZNPYFVOE",
					 "BDFHJLCPRTXVZNYEIWGAKMUSQO",
					 "ESOVPZJAYQUIRHXLNFTGKDCMWB",
					 "VZBRGITYUPSDNHLXAWMJQOFECK"]
	notches = Int[17,5,22,10,26]

	rotor1 = _keystr_to_dict(rotor_layouts[rotors[1]])
	notch1 = notches[rotors[1]]
	rotor2 = _keystr_to_dict(rotor_layouts[rotors[2]])
	notch2 = notches[rotors[2]]
	rotor3 = _keystr_to_dict(rotor_layouts[rotors[3]])
	notch3 = notches[rotors[3]]

	rotor1_inv = Dict{Char, Char}(Pair{Char, Char}[reverse(a) for a in rotor1])
	rotor2_inv = Dict{Char, Char}(Pair{Char, Char}[reverse(a) for a in rotor2])
	rotor3_inv = Dict{Char, Char}(Pair{Char, Char}[reverse(a) for a in rotor3])

	# apply the key as part of initialisation; incorporates ring
	key_offsets = Int[26 + Int(ch) - 65 for ch in key]
	notch1 = (key_offsets[1] * 26 + notch1 - key_offsets[1]) % 26
	notch2 = (key_offsets[2] * 26 + notch2 - key_offsets[2]) % 26
	notch3 = (key_offsets[3] * 26 + notch3 - key_offsets[3]) % 26

	key_offsets = key_offsets .- Int[Int(ring[i]) - 65 for i in 1:3]

	# We receive a character; the rotors increment; then:
	# the character goes through the plugboard
	# the character then goes through rotor3, then rotor2, then rotor1
	# then the reflector, then the inverse of rotor 1, 2, 3
	# finally the plugboard again
	plugboard_dict = Dict(vcat(parsed_stecker, map(reverse, parsed_stecker)))

    ans = IOBuffer()

    rotor3movements = key_offsets[3]
	rotor2movements = key_offsets[2]
	rotor1movements = key_offsets[1]

	for (i, working_ch) in enumerate(plaintext)
		# rotate rotors
		notch3 -= 1
		rotor3movements += 1
		if notch3 == 0
			notch3 = 26

			rotor2movements += 1
			notch2 -= 1
			if notch2 == 0
				notch2 = 26
				rotor1movements += 1
				notch1 -= 1

				if notch1 == 0
					notch1 = 26
				end
			end
		end

		# double step of rotor
		if notch3 == 25 && notch2 == 1
			notch2 = 26
			rotor2movements += 1
			rotor1movements += 1
			notch1 -= 1
			if notch1 == 0
				notch1 = 26
			end
		end


		# plugboard
		working_ch = first(encrypt_monoalphabetic(working_ch, plugboard_dict))

		# rotors
		# comes in as…
		working_ch = Char(65 + ((rotor3movements + Int(working_ch) - 65) % 26))
		working_ch = first(encrypt_monoalphabetic(working_ch, rotor3))

 		# comes in as…
 		working_ch = Char(65 + (((26 * rotor3movements) - rotor3movements + rotor2movements + Int(working_ch) - 65) % 26))
		working_ch = encrypt_monoalphabetic(working_ch, rotor2)[1]

 		# comes in as…
 		working_ch = Char((((26 * rotor2movements) + Int(working_ch) - 65 - rotor2movements + rotor1movements) % 26) + 65)
		working_ch = first(encrypt_monoalphabetic(working_ch, rotor1))

		# reflector
		# comes in as…
		working_ch = Char((26 * rotor1movements + Int(working_ch) - 65 - rotor1movements) % 26 + 65)
		working_ch = first(encrypt_monoalphabetic(working_ch, reflector))

		# rotors
		# comes in as…
		working_ch = Char((Int(working_ch) - 65 + rotor1movements) % 26 + 65)

		# we use encrypt_monoalphabetic and inverse-dictionaries already computed, for speed,
		# where it is more natural to use decrypt_monoalphabetic
		working_ch = uppercase(first(encrypt_monoalphabetic(working_ch, rotor1_inv)))
 		working_ch = Char(65 + ((rotor1movements * 26 + rotor2movements - rotor1movements + Int(working_ch) - 65) % 26))
		working_ch = uppercase(first(encrypt_monoalphabetic(working_ch, rotor2_inv)))
 		working_ch = Char(65 + ((26 * rotor2movements + rotor3movements - rotor2movements + Int(working_ch) - 65) % 26))
		working_ch = uppercase(first(encrypt_monoalphabetic(working_ch, rotor3_inv)))

		# plugboard
		# comes in as…
		working_ch = Char(65 + (((26 * rotor3movements) - rotor3movements + Int(working_ch) - 65) % 26))
		working_ch = first(encrypt_monoalphabetic(working_ch, plugboard_dict))

		print(ans, working_ch)
	end

	return uppercase(String(take!(ans)))
end

"""
See `encrypt_enigma` as this function uses identical arguments.
"""
decrypt_enigma(args1...; args2...) =
	lowercase(encrypt_enigma(args1...; args2...))
