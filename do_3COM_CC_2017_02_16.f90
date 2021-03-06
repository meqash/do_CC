program do_3COM_CC ! 2017/02/16 
use sacio
implicit none
integer,parameter:: nmax=4000000,nstmax=2000
type(sac_head):: sachead1,sachead2
integer iseg,dsec,multpt
integer nzhour,nzmin,nzsec,dorot
integer nsmpl,nerr,nseg,dseg,npow
integer year_b,year_e,day_b,day_e
integer nst1,nst2,i,nh,j,nlen,nn,is1,is2
integer jday,npts,npt2,icc(10000),itemp
integer ibeg1,ibeg2,iend1,iend2,ibeg,iend
integer iy,id,ih,ist,nsamp,is,it,dotl,dopw,dotf
integer begday,endday,ic1,ic2,numcc(3,3),nptseg
real t1,t2,dt
real sig1(nmax,3),sig2(nmax,3),signcc(nmax,3,3),sigrot(nmax,3,3)
real sig_re(nmax),sig_im(nmax)
!complex sig1(nmax,3)
character (180)command
character (2)note(3,3)
character (3)com(3),comm
character (20)year_day,nd
character (80)name1z,name1n,name1e
character (2)net1(nstmax),net2(nstmax)
character (7)sta1(nstmax),sta2(nstmax)
character (80)name1,name2,dir_day,dir
character (80)name2z,name2n,name2e,name
character (100)output_ncc(3,3),output
character (100)output_tl_pcc,output_pw_pcc
character (80)dirinn,dirout,input,list1,list2,output_tmp
character (180)sac1,sac2,sacfile1(3),sacfile2(3)
logical ext
if (iargc().ne.1)then
   write(*,*)'Usage: do_3COM_CC param.dat '
   write(*,*)'param.dat is like:'
   write(*,*)'station list1'
   write(*,*)'station list2'
   write(*,*)'year_b day_b year_e day_e'
   write(*,*)'dsec multpt com nlen dorot'
   write(*,*)'/directory of SAC file/'
   write(*,*)'/output directory/'
   stop
endif
call getarg(1,input)
open(10,file=input)
read(10,*)list1
read(10,*)list2
read(10,*)year_b,day_b,year_e,day_e
read(10,*)dsec,multpt,comm,npt2,dorot
read(10,*)dirinn
read(10,*)dirout
close(10)
! read the parameters done
! e.g., comm="BH"
com(1)=trim(comm)//'Z'
com(2)=trim(comm)//'N'
com(3)=trim(comm)//'E'
note(1,1)="zz"
note(1,2)="zr"
note(1,3)="zt"
note(2,1)="rz"
note(2,2)="rr"
note(2,3)="rt"
note(3,1)="tz"
note(3,2)="tr"
note(3,3)="tt"
open(11,file=list1)                       ! read in station lists
do i=1,nstmax
   read(11,*,err=13,end=13) net1(i),sta1(i)
enddo
13 close(11)
nst1=i-1                                  ! number of stations

open(11,file=list1)                       ! read in station lists
do i=1,nstmax
   read(11,*,err=14,end=14) net2(i),sta2(i)
enddo
14 close(11)
nst2=i-1                                  ! number of stations

if(multpt.ge.100)stop "Hi the overlapping percentage is too big!"
write(name,'(i0,"_",i3.3,"_",i0,"_",i3.3)')year_b,day_b,year_e,day_e
nsmpl=2*npt2+1                           ! number of output points
call cpu_time(t1)
dseg=int((1-real(multpt)/100.0)*dsec)    ! the left points without overlapping
nseg=int((86400-dsec)/dseg)+1            ! number of segments per day
do iy=year_b,year_e                      ! loop over year
   jday=365
   if(mod(iy,4).eq.0.and.mod(iy,100).ne.0.or.mod(iy,400).eq.0)jday=366
   endday=day_e
   if(iy.ne.year_e)endday=jday
   begday=day_b
   if(iy.ne.year_b)begday=1
   do id=begday,endday                   ! loop over day
      write(year_day,'(i0,"_",i3.3)')iy,id
      do iseg=1,nseg                     ! loop over each segment
         nzhour=(iseg-1)*dseg/3600
         nzmin=mod((iseg-1)*dseg,3600)/60
         nzsec=mod(mod((iseg-1)*dseg,3600),60)
         do is1=1,nst1                   ! loop over station 1
            do ic1=1,3                   ! check whether all three components exist
               write(sacfile1(ic1),'(1a,"/",1a,"/",1a,"_",i2.2,"_",i2.2,"_",i2.2,"_",1a,"_",1a,"_",1a,".SAC")')&
               trim(dirinn),trim(year_day),trim(year_day),nzhour,nzmin,nzsec,&
               trim(net1(is1)),trim(sta1(is1)),trim(com(ic1))
               inquire(file=sacfile1(ic1),exist=ext)
               it=0
               if(.not.ext)exit
               call read_sachead(sacfile1(ic1),sachead1,nerr)
               call read_sac(sacfile1(ic1),sig1(:,ic1),sachead1,nerr)
               if(nerr.eq.-1)exit
               it=ic1
            enddo              ! check station one done!
            if(it.ne.3)cycle   ! if all three components of station 1 exist
            do is2=1,nst2      ! loop over station 2
               write(command,'("mkdir -p",1x,1a,"/",1a,"_",1a,"/",1a,"_",1a,"_",1a,"_",1a,1x,"2>/dev/null")')&
               trim(dirout),trim(net1(is1)),trim(sta1(is1)),trim(net1(is1)),trim(sta1(is1)),trim(net2(is2)),trim(sta2(is2))                  ! mkdir for output directory
               call system(command)
               do ic2=1,3      ! check whether all three components of station two exist
                  write(sacfile2(ic2),'(1a,"/",1a,"/",1a,"_",i2.2,"_",i2.2,"_",i2.2,"_",1a,"_",1a,"_",1a,".SAC")')&
                  trim(dirinn),trim(year_day),trim(year_day),nzhour,nzmin,nzsec,&
                  trim(net2(is2)),trim(sta2(is2)),trim(com(ic2))
                  inquire(file=sacfile2(ic2),exist=ext)
                  it=0
                  if(.not.ext)exit
                  call read_sachead(sacfile2(ic2),sachead2,nerr)
                  call read_sac(sacfile2(ic2),sig2(:,ic2),sachead2,nerr)
                  if(nerr.eq.-1)exit
                  it=ic2
               enddo                 ! check and read station two done
               if(it.ne.3)cycle     ! if all three components of station 2 exist
               if(sachead2%delta.ne.sachead1%delta)exit
               nsamp=sachead1%npts
               do ic1=1,3                     ! loop over com1
                  do ic2=1,3                  ! loop over com2
                     write(*,'("doncc: ",1a,1x,1a)')trim(sacfile1(ic1)),trim(sacfile2(ic2))
                     write(output_ncc(ic1,ic2),'(1a,"/",1a,"_",1a,"/",1a,"_",1a,"_",1a,"_",1a,&
                     "/ncc_",1a,"_",i2.2,"_",i2.2,"_",i2.2,"_",1a,"_",1a,"_",1a,"_",1a,&
                     "_",1a,"_",1a,".SAC")')trim(dirout),trim(net1(is1)),trim(sta1(is1)),&
                     trim(net1(is1)),trim(sta1(is1)),trim(net2(is2)),trim(sta2(is2)),trim(year_day),&
                     nzhour,nzmin,nzsec,trim(net1(is1)),trim(sta1(is1)),trim(net2(is2)),&
                     trim(sta2(is2)),trim(com(ic1)),trim(com(ic2))
                     if(dorot.eq.1)&
                     write(output_ncc(ic1,ic2),'(1a,"/",1a,"_",1a,"/",1a,"_",1a,"_",1a,"_",1a,&
                     "/ncc_",1a,"_",i2.2,"_",i2.2,"_",i2.2,"_",1a,"_",1a,"_",1a,"_",1a,&
                     ".",1a)')trim(dirout),trim(net1(is1)),trim(sta1(is1)),&
                     trim(net1(is1)),trim(sta1(is1)),trim(net2(is2)),trim(sta2(is2)),trim(year_day),&
                     nzhour,nzmin,nzsec,trim(net1(is1)),trim(sta1(is1)),trim(net2(is2)),&
                     trim(sta2(is2)),note(ic1,ic2)
                     !call do_ncc(nsamp,npow,npt2,dt,sig1(:,ic1),sig2(:,ic2),signcc(:,ic1,ic2))
                     call do_ncc(nsamp,sig1(:,ic1),sig2(:,ic2),signcc(:,ic1,ic2),npt2,dt)
                     !call write_ncf_sac(output_ncc,signcc,sachead1,sachead2,nsmpl,1,nerr)
                  enddo ! end loop over com2
               enddo    ! end loop over com1      
               if(dorot.eq.1)then
                  call rot9com(sachead1,sachead2,nsmpl,signcc,sigrot)
                  do ic1=1,3
                     do ic2=1,3
                        call write_ncf_sac(output_ncc(ic1,ic2),sigrot(:,ic1,ic2),sachead1,sachead2,nsmpl,dt,1,nerr)
                     enddo
                  enddo
               else
                  do ic1=1,3
                     do ic2=1,3
                        call write_ncf_sac(output_ncc(ic1,ic2),signcc(:,ic1,ic2),sachead1,sachead2,nsmpl,dt,1,nerr)
                     enddo
                  enddo
               endif
            enddo       ! end loop over station2
         enddo          ! end loop over station1
      enddo             ! end loop over segment
   enddo                ! end loop over day
enddo                   ! end loop over year
call cpu_time(t2)
write(*,'("Segment length:",i2,"h Overlaping:",i2.2,"%, Time costs: ",f17.3,"s")')dsec,multpt,t2-t1
end program
