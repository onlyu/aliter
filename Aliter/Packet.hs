module Aliter.Packet (
    sent,
    subPack,
    received,
    sendPacket,
    buildSub,
    neededSub,
    sendPacketSub
) where

import Aliter.Hex
import Aliter.Pack
import Aliter.Util (debug)

import Network.Socket


sent :: [(Int, (String, [String]))]
sent = [
       -- Login server
         (0x69, ("hLlLl24shB", ["servers"])) -- Logged in
       , (0x6a, ("B20s", [])) -- Login failed

       -- Char server
       , (0x6b, ("h20s", ["character"])) -- List characters
       , (0x6c, ("h", [])) -- Character selection failed / char server error
       , (0x6d, ("?", ["character"])) -- Character creation
       , (0x6e, ("h", [])) -- Character creation failed
       , (0x6f, ("", [])) -- Character deleted
       , (0x70, ("h", [])) -- Character deletion failed
       , (0x71, ("l16s4sh", [])) -- Character selected

       -- Zone server
       , (0x283, ("l", [])) -- Acknowledge connection
       ]

subPack :: [(String, String)]
subPack = [ ("servers", "4sh20shhh")
          , ("character", "5l8s3l17h24s6Bhh")
          ]

received :: [(Int, (String, [String]))]
received = [
           -- Login server
             (0x64, ("l24s24sB", ["packetVersion", "username", "password", "region"]))

           -- Character server
           , (0x65, ("lLLxxB", ["accountID", "loginIDa", "loginIDb", "gender"]))
           , (0x66, ("b", ["charNum"]))
           , (0x67, ("24s8BxBx", ["name", "str", "agi", "vit", "int", "dex", "luk", "charNum", "hairStyle", "hairColor"]))
           , (0x68, ("l40s", ["characterID", "email"]))
           , (0x187, ("l", ["kaAccountID"]))
           ]

sendPacket :: Socket -> Int -> [Pack] -> IO Int
sendPacket s n xs = case lookup n sent of
                         Just (f, _) -> send s (unhex (pack ('h':f) (UInt n:xs)))
                         Nothing -> error ("Cannot send unknown packet: " ++ intToH 2 n)

buildSub :: String -> [[Pack]]-> String
buildSub n vs = case lookup n subPack of
                     Just f -> packMany f vs
                     Nothing -> error ("Unknown subpacket: " ++ n)

neededSub :: String -> [[Pack]] -> Int
neededSub s ps = case lookup s subPack of
                      Just f -> needed f * length ps
                      Nothing -> error ("Unknown subpacket: " ++ s)

sendPacketSub :: Socket -> Int -> [Pack] -> [[[Pack]]] -> IO Int
sendPacketSub s n xs ps = case lookup n sent of
                               Just (f, ss) -> let subs = concat $ zipWith buildSub ss ps
                                                   len = needed ('h':f) + sum (zipWith neededSub ss ps)
                                                   main = pack ('h':f) (UInt n : UInt len : xs)
                                               in send s (unhex (main ++ subs))
                               Nothing -> error ("Cannot send unknown packet: " ++ intToH 2 n)
