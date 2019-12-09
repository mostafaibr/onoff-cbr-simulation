set ns [new Simulator]
set traceFile [open out_project.tr w]

#$ns trace-all $traceFile slows simulation

#--------------------------------------------------
#declaring variables
set node0 [$ns node]
set node1 [$ns node]

set b [lindex $argv 0]
set lambdaAverage [lindex $argv 1]
set averageRateCBR [expr 80 - $lambdaAverage]Mb
set numberBlocks [lindex $argv 2]
set blockDuration [lindex $argv 2]

set bandwidth 100Mb
set delay 1ms
set queueSize 10000000000
set burstTime 0.001
set idleTime [expr ($b - 1) * $burstTime]

set peakRateONOFF [expr $b * $lambdaAverage]Mb
set packetSize 1000
set int_restart_cbr 10

set startTime 0.0
set stopTime 20.0

set sumZt 0.0
set sumZt2 0.0
set nbBlocks 0.0
set drops 0
#-----------------------------------
#creating topology
$ns duplex-link $node0 $node1 $bandwidth $delay DropTail
$ns queue-limit $node0 $node1 $queueSize

set sourceAgent [new Agent/UDP]
$sourceAgent set packetSize 1000

set destinationAgent [new Agent/Null]

$ns attach-agent $node0 $sourceAgent
$ns attach-agent $node1 $destinationAgent

$ns connect $sourceAgent $destinationAgent

set sourceONOFF [new Application/Traffic/Exponential]

$sourceONOFF set burst_time_ $burstTime 
$sourceONOFF set idle_time_ $idleTime  
$sourceONOFF set rate_ $peakRateONOFF
$sourceONOFF set packetSize_ $packetSize   
$sourceONOFF attach-agent $sourceAgent

#---------------------------------------------------------------------
#concurrent CBR Application

set udpAgent [new Agent/UDP]
$udpAgent set packetSize $packetSize

set nullAgent [new Agent/Null]

#attaching agents to nodes
$ns attach-agent $node0 $udpAgent
$ns attach-agent $node1 $nullAgent

#connecting both agents
$ns connect $udpAgent $nullAgent

#creating cbr traffic
set cbrApplication [new Application/Traffic/CBR]
$cbrApplication set packet_size_ $packetSize
$cbrApplication set rate_ $averageRateCBR
$cbrApplication set random_ 1

$cbrApplication attach-agent $udpAgent

#----------------------------------------------------------------------
#attaching monitors
$sourceAgent set fid_ 1
#declare global Monitor
set globalMonitor [$ns makeflowmon Fid]
#attach monitor
$ns attach-fmon [$ns link $node0 $node1] $globalMonitor
#this object stores all response times, a response time per packet
set samples_object [new Samples]

#attach the object to monitor
$globalMonitor set-delay-samples $samples_object

#create a flow montior for ON/OFF
set onoffMonitor [new QueueMonitor/ED/Flow]
set onoffSamples [new Samples]
$onoffMonitor set-delay-samples $onoffSamples

set classif [$globalMonitor classifier]

#create an entry inside the classifier 
set slot1 [$classif installNext $onoffMonitor]

$classif set-hash auto $sourceAgent $destinationAgent 1 $slot1

#----------------------------------------------------------------------
#finish procedure
proc finish { } { 
	global ns traceFile
	$ns flush-trace
	close $traceFile
	exit 0
}

#procedure for restarting CBR
proc restartCBR { } {
	global cbrApplication int_restart_cbr ns udpAgent packetSize averageRateCBR
	$cbrApplication stop
	delete $cbrApplication
	set cbrApplication [new Application/Traffic/CBR]
	$cbrApplication set packetSize_ $packetSize
	$cbrApplication set rate_ $averageRateCBR
	$cbrApplication attach-agent $udpAgent
	$cbrApplication start 
	$ns at [expr [$ns now] + $int_restart_cbr] "restartCBR"
}

proc computeResponseTime { } {
	global ns onoffSamples samples_object sumZt sumZt2 blockDuration nbBlocks drops globalMonitor

	set onoffReponseTime [$onoffSamples mean]

	#puts " my on/off response time : $onoffReponseTime"
	set sumZt [expr $sumZt + $onoffReponseTime]
	set sumZt2 [expr $sumZt2 + $onoffReponseTime * $onoffReponseTime]
	set nbBlocks [expr $nbBlocks + 1]

	set drops [expr $drops + [$globalMonitor set pdrops_]]

	$onoffSamples reset
	$samples_object reset

	$ns at [expr [$ns now] + $blockDuration] "computeResponseTime"
}

#procedure to compute error
proc computeEquations { } {
	global sumZt sumZt2 nbBlocks drops b peakRateONOFF averageRateCBR
	set var [expr (1/($nbBlocks - 1)) * ($sumZt2 - ($sumZt * $sumZt * 1.0/$nbBlocks))]
	set sd [expr sqrt($var)]
	set errZt [expr 4.5 * $sd]
	set errZnt [expr (1.0/sqrt($nbBlocks)) * $errZt]
	set znt [expr 1.0/$nbBlocks * $sumZt]
	set relativeErr [expr ($errZnt*1.0/$znt) *100]
	#puts "sumZt : $sumZt"
	#puts "sumZt2 : $sumZt2"
	#puts "var : $var"
	#puts "sd : $sd"
	#puts "errZt : $errZt"
	#puts "errZnt : $errZnt"
	#puts "------------------------------------------------------"
	#puts "timeB : $nbBlocks"
	#puts "znt : $znt"
	#puts "relativeErr : $relativeErr"
	#puts "drops: $drops"
	puts "$b $znt $relativeErr $drops $nbBlocks $peakRateONOFF $averageRateCBR"
	
}



#procedure for printing results
proc printResults { } { 

	global ns sumZt sumZt2

	

}

#------------------0-----------------
#scheduling event

#$ns at $int_restart_cbr "restartCBR"
#$ns at $startTime "$cbrApplication start"
#$ns at $stopTime "$cbrApplication stop" error, error when stoping a pointer doesn't exist
#$ns at [expr $blockDuration * $numberBlocks + 5] "printResults"
$ns at $startTime "$sourceONOFF start"
$ns at [expr $blockDuration * $numberBlocks] "$sourceONOFF stop"
$ns at $blockDuration "computeResponseTime"
$ns at [expr $blockDuration * $numberBlocks + 5] "computeEquations"
$ns at [expr $blockDuration * $numberBlocks + 7] "finish"
$ns run
